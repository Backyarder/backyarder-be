# Daily rain and low temperatures from Open-Meteo (free, no key, no limits
# that matter for a handful of gardens). Two days back and three days ahead.
class WeatherService
  BASE_URL = "https://api.open-meteo.com/".freeze
  PAST_DAYS = 2
  FORECAST_DAYS = 3

  # Returns { days: [{ date:, rain_in:, low_f: }, ...] } or nil on any failure.
  def forecast(latitude, longitude)
    return nil if latitude.nil? || longitude.nil?

    response = Faraday.new(BASE_URL).get("v1/forecast",
                                         latitude: latitude, longitude: longitude,
                                         daily: "precipitation_sum,temperature_2m_min",
                                         past_days: PAST_DAYS, forecast_days: FORECAST_DAYS,
                                         timezone: "auto", temperature_unit: "fahrenheit",
                                         precipitation_unit: "inch")
    return nil unless response.success?

    data = JSON.parse(response.body, symbolize_names: true)
    daily = data[:daily] || {}
    dates = daily[:time] || []
    rain = daily[:precipitation_sum] || []
    lows = daily[:temperature_2m_min] || []
    return nil if dates.empty?

    days = dates.each_with_index.map do |date, i|
      { date: date, rain_in: rain[i].to_f.round(2), low_f: lows[i]&.to_f&.round(1) }
    end
    { days: days }
  rescue Faraday::Error, JSON::ParserError
    nil
  end
end
