require "set"

# Everything worth telling a user about their garden today: plants due for
# water, recent rain that may cover it, and frost in the forecast.
class GardenAlerts
  RAIN_SKIP_INCHES = 0.5   # this much rain on one day counts as a watering
  FROST_F = 32.0
  WEATHER_TTL = 3 * 60 * 60

  attr_reader :user

  def initialize(user, now: Time.now, weather_service: WeatherService.new)
    @user = user
    @now = now
    @weather_service = weather_service
  end

  def needs_water
    @needs_water ||= user.garden.cells.order(:id).select { |cell| cell.needs_water?(@now, rained_at: rain_credit.call(cell)) }
  end

  # The most recent day before today with at least RAIN_SKIP_INCHES of rain,
  # as a time (evening of that day), or nil. Today's total is still a
  # forecast, so it doesn't count until tomorrow.
  def rained_at
    return @rained_at if defined?(@rained_at)

    day = (weather&.dig(:days) || [])
      .select { |d| d[:date] < today && d[:rain_in].to_f >= RAIN_SKIP_INCHES }
      .max_by { |d| d[:date] }
    @rained_at = day && Time.utc(*day[:date].split("-").map(&:to_i), 18)
  end

  # cell -> rained_at for outdoor plants, nil for houseplants (rain doesn't
  # reach them). Built-in houseplants are identified by their collection.
  def rain_credit
    @rain_credit ||= begin
      credit = rained_at
      indoor = credit ? indoor_plant_ids : Set.new
      ->(cell) { credit && !indoor.include?(cell.plant_id) ? credit : nil }
    end
  end

  def indoor_plant_ids
    ids = user.garden.cells.where.not(plant_id: nil).distinct.pluck(:plant_id)
    PlantDetail.where(plant_id: ids).select { |r| r.summary_hash[:collection] == "indoor" }.map(&:plant_id).to_set
  end

  # Cached on the user; nil when the user has no coordinates or the service failed.
  def weather
    return @weather if defined?(@weather)
    return @weather = nil if user.latitude.nil? || user.longitude.nil?

    if user.weather.present? && user.weather_fetched_at && user.weather_fetched_at > @now - WEATHER_TTL
      return @weather = JSON.parse(user.weather, symbolize_names: true)
    end

    fetched = @weather_service.forecast(user.latitude, user.longitude)
    if fetched
      user.update_columns(weather: JSON.generate(fetched), weather_fetched_at: @now)
      @weather = fetched
    else
      @weather = user.weather.present? ? JSON.parse(user.weather, symbolize_names: true) : nil
    end
  end

  def today
    @now.utc.to_date.iso8601
  end

  # Rain over the two days before today plus today.
  def recent_rain_in
    days = weather&.dig(:days) || []
    since = (@now.utc.to_date - 2).iso8601
    days.select { |d| d[:date] >= since && d[:date] <= today }.sum { |d| d[:rain_in].to_f }.round(2)
  end

  def rain_covers_watering?
    recent_rain_in >= RAIN_SKIP_INCHES
  end

  # First upcoming day (today or later) at or below freezing, or nil.
  def frost
    days = weather&.dig(:days) || []
    days.find { |d| d[:date] >= today && d[:low_f] && d[:low_f] <= FROST_F }
  end

  def any?
    needs_water.any? || !frost.nil?
  end

  def to_h
    {
      date: today,
      needs_water: needs_water.map { |c| { location_id: c.location_id, name: c.name, plant_id: c.plant_id, watering: c.watering, next_water_at: c.next_water_at(rained_at: rain_credit.call(c))&.utc&.iso8601 } },
      recent_rain_in: recent_rain_in,
      rain_watered_on: rained_at&.to_date&.iso8601,
      rain_covers_watering: rain_covers_watering?,
      frost: frost && { date: frost[:date], low_f: frost[:low_f] },
      weather_available: !weather.nil?,
      zip_code: user.zip_code
    }
  end

  # Plain-text email body, or nil when there is nothing to say.
  def message
    return nil unless any?

    lines = ["Good morning! Here's your Backyarder report for #{today}.", ""]
    if needs_water.any?
      lines << "Plants due for water (#{needs_water.size}):"
      needs_water.each { |c| lines << "  - #{c.name} in #{c.location_id} (#{c.watering} watering)" }
      lines << ""
    end
    lines << "Rain on #{rained_at.to_date.strftime('%A')} counted as a watering for your outdoor plants." if rained_at
    if frost
      lines << "Frost warning: a low of #{frost[:low_f]}F is forecast for #{frost[:date]}. Cover or bring in tender plants."
    end
    lines << ""
    lines << "Open your garden: #{ENV.fetch('APP_BASE_URL', 'https://backyarder.vercel.app')}"
    lines.reject(&:nil?).join("\n")
  end
end
