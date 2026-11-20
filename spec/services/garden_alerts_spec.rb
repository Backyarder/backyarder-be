require "spec_helper"

RSpec.describe GardenAlerts do
  let(:now) { Time.utc(2026, 11, 12, 14, 0, 0) }
  let(:day) { 24 * 60 * 60 }
  let(:user) { User.create!(email: "a@example.com", password: "gardening1", latitude: 34.3, longitude: -83.8) }

  def forecast_body(rain: [0, 0, 0, 0, 0], lows: [45, 44, 46, 37, 33])
    dates = (-2..2).map { |o| (now.to_date + o).iso8601 }
    JSON.generate(daily: { time: dates, precipitation_sum: rain, temperature_2m_min: lows })
  end

  def stub_weather(**opts)
    stub_request(:get, %r{api\.open-meteo\.com/v1/forecast}).to_return(status: 200, body: forecast_body(**opts), headers: { "Content-Type" => "application/json" })
  end

  def plant(location, watering, watered_days_ago)
    user.garden.cells.find_by(location_id: location).update!(status: :locked, name: "Plant #{location}", plant_id: 1, content_type: "Plant", watering: watering, planted_at: now - 30 * day, last_watered_at: now - watered_days_ago * day)
  end

  it "lists only the plants that are due" do
    stub_weather
    plant("A1", :Frequent, 3)   # due (2 day interval)
    plant("A2", :Average, 3)    # not due (5 day interval)
    plant("A3", :Minimum, 11)   # due (10 day interval)

    alerts = described_class.new(user, now: now)
    expect(alerts.needs_water.map(&:location_id)).to eq(%w[A1 A3])
    expect(alerts.to_h[:needs_water].first).to include(location_id: "A1", watering: "Frequent")
    expect(alerts.any?).to be(true)
  end

  it "reports recent rain and whether it covers the watering" do
    stub_weather(rain: [0.3, 0.1, 0.2, 0, 0])
    alerts = described_class.new(user, now: now)

    expect(alerts.recent_rain_in).to eq(0.6)
    expect(alerts.rain_covers_watering?).to be(true)

    stub_weather(rain: [0, 0.1, 0, 0, 0])
    dry_user = User.create!(email: "dry@example.com", password: "gardening1", latitude: 34.3, longitude: -83.8)
    expect(described_class.new(dry_user, now: now).rain_covers_watering?).to be(false)
  end

  it "warns about the first upcoming freezing day and ignores past ones" do
    stub_weather(lows: [20, 25, 40, 36, 31.5])
    alerts = described_class.new(user, now: now)

    expect(alerts.frost).to include(date: (now.to_date + 2).iso8601, low_f: 31.5)
    expect(alerts.any?).to be(true)
    expect(alerts.message).to include("Frost warning", "31.5F")
  end

  it "caches the forecast on the user for a few hours" do
    request = stub_weather
    described_class.new(user, now: now).weather
    described_class.new(user.reload, now: now + 60).weather
    expect(request).to have_been_requested.once

    described_class.new(user.reload, now: now + GardenAlerts::WEATHER_TTL + 1).weather
    expect(request).to have_been_requested.twice
  end

  it "works without coordinates or when the weather service is down" do
    no_coords = User.create!(email: "b@example.com", password: "gardening1")
    expect(described_class.new(no_coords, now: now).to_h).to include(weather_available: false, frost: nil, recent_rain_in: 0.0)

    stub_request(:get, %r{api\.open-meteo\.com}).to_return(status: 500, body: "")
    expect(described_class.new(user, now: now).weather).to be_nil
    expect(described_class.new(user, now: now).message).to be_nil
  end

  describe "rain counts as a watering" do
    it "pushes back the due date of outdoor plants after a day with half an inch or more" do
      stub_weather(rain: [0, 0.7, 0, 0, 0]) # yesterday: 0.7 in
      plant("A1", :Frequent, 3)              # would be due (2-day interval)

      alerts = described_class.new(user, now: now)

      expect(alerts.rained_at).to eq(Time.utc(*(now.to_date - 1).to_s.split("-").map(&:to_i), 18))
      expect(alerts.needs_water).to be_empty
      expect(alerts.to_h[:rain_watered_on]).to eq((now.to_date - 1).iso8601)
      cell = user.garden.cells.find_by(location_id: "A1")
      expect(cell.next_water_at(rained_at: alerts.rain_credit.call(cell))).to eq(alerts.rained_at + 2 * day)
    end

    it "ignores today's forecast rain and light rain" do
      stub_weather(rain: [0.3, 0.4, 1.2, 0, 0]) # today's 1.2 in hasn't necessarily fallen yet
      plant("A1", :Frequent, 3)

      alerts = described_class.new(user, now: now)

      expect(alerts.rained_at).to be_nil
      expect(alerts.needs_water.map(&:location_id)).to eq(["A1"])
    end

    it "never credits rain to plants in an indoor area, and names the area in the digest" do
      stub_weather(rain: [0, 0.9, 0, 0, 0])
      plant("A1", :Frequent, 3)
      sunroom = Garden.create_for!(user, name: "Sunroom", indoor: true)
      sunroom.cells.find_by(location_id: "C4").update!(status: :locked, name: "Pothos", plant_id: 55, content_type: "Plant", watering: :Frequent, planted_at: now - 3 * day)

      alerts = described_class.new(user, now: now)

      expect(alerts.needs_water.map(&:name)).to eq(["Pothos"])
      expect(alerts.to_h[:needs_water].first).to include(garden_id: sunroom.id, garden_name: "Sunroom")
      expect(alerts.message).to include("Pothos in Sunroom, C4")
    end

    it "skips frost warnings when every area is indoors" do
      stub_weather(rain: [0, 0, 0, 0, 0], lows: [50, 50, 50, 28, 50])
      plant("A1", :Average, 1)
      user.garden.update!(indoor: true)

      expect(described_class.new(user, now: now).frost).to be_nil
      user.garden.update!(indoor: false)
      expect(described_class.new(user, now: now).frost).not_to be_nil
    end

    it "never credits rain to houseplants" do
      stub_weather(rain: [0, 0.9, 0, 0, 0])
      plant("A1", :Frequent, 3)
      user.garden.cells.find_by(location_id: "A1").update!(plant_id: 777, name: "snake plant")
      PlantDetail.create!(plant_id: 777, common_name: "snake plant", summary: JSON.generate(collection: "indoor"))

      alerts = described_class.new(user, now: now)

      expect(alerts.needs_water.map(&:location_id)).to eq(["A1"])
    end

    it "remembers rain from more than two days ago, but leaves it out of the two-day total" do
      days = (-6..2).map { |o| (now.to_date + o).iso8601 }
      rain = [0, 0.8, 0, 0, 0, 0, 0, 0, 0] # five days ago
      stub_request(:get, %r{api\.open-meteo\.com/v1/forecast}).to_return(status: 200, headers: { "Content-Type" => "application/json" },
        body: JSON.generate(daily: { time: days, precipitation_sum: rain, temperature_2m_min: Array.new(9, 50) }))
      plant("A1", :Minimum, 9) # watered nine days ago: due tomorrow, or in five days counting the rain

      alerts = described_class.new(user, now: now)

      expect(alerts.rained_at.to_date).to eq(now.to_date - 5)
      expect(alerts.recent_rain_in).to eq(0.0)
      expect(alerts.needs_water).to be_empty
    end

    it "doesn't move a watering that happened after the rain" do
      stub_weather(rain: [0.8, 0, 0, 0, 0]) # two days ago
      plant("A1", :Average, 1)              # watered yesterday

      alerts = described_class.new(user, now: now)
      cell = user.garden.cells.find_by(location_id: "A1")

      expect(cell.next_water_at(rained_at: alerts.rain_credit.call(cell))).to eq(cell.last_watered_at + 5 * day)
      expect(alerts.message).to be_nil
    end
  end

  it "writes a readable message only when there is something to say" do
    stub_weather(rain: [0.4, 0.2, 0, 0, 0])
    expect(described_class.new(user, now: now).message).to be_nil

    plant("B2", :Frequent, 3)
    message = described_class.new(user.reload, now: now).message
    expect(message).to include("Plants due for water (1)", "Plant B2 in B2", "https://backyarder.vercel.app")
    expect(message).not_to include("counted as a watering") # 0.4 and 0.2 in: no single day reached half an inch
  end
  describe "per-plant watering plans" do
    def month_of_weather(rain_days_ago: nil)
      days = (-30..2).map { |o| (now.to_date + o).iso8601 }
      rain = days.map { |d| rain_days_ago && d == (now.to_date - rain_days_ago).iso8601 ? 0.8 : 0 }
      stub_request(:get, %r{api\.open-meteo\.com/v1/forecast}).to_return(status: 200, headers: { "Content-Type" => "application/json" },
        body: JSON.generate(daily: { time: days, precipitation_sum: rain, temperature_2m_min: Array.new(days.size, 50) }))
    end

    def butterfly_bush(location, watered_days_ago, plot: user.garden, **attrs)
      PlantDetail.find_or_create_by!(plant_id: 900_483) do |r|
        r.summary = JSON.generate(type: "Deciduous shrub", cycle: "Perennial", watering: "Minimum", drought_tolerant: true, collection: "trees")
      end
      plot.cells.find_by(location_id: location).update!({ status: :locked, name: "butterfly bush", plant_id: 900_483, content_type: "Plant", watering: :Minimum,
                                                          planted_at: now - 200 * day, last_watered_at: now - watered_days_ago * day }.merge(attrs))
    end

    it "leaves an established butterfly bush alone for four weeks, and rain three weeks ago resets it" do
      month_of_weather
      butterfly_bush("A1", 20)
      butterfly_bush("A2", 29)
      plant("A3", :Minimum, 11) # unknown plant: old 10-day interval

      alerts = described_class.new(user, now: now)
      expect(alerts.needs_water.map(&:location_id)).to eq(%w[A2 A3])
      expect(alerts.to_h[:needs_water].first).to include(location_id: "A2", watering_days: 28)
      expect(alerts.message).to include("butterfly bush in A2 (every 28 days)", "Plant A3 in A3 (every 10 days)")
      expect(alerts.counts[user.garden.id]).to eq(plants: 3, needs_water: 2)

      month_of_weather(rain_days_ago: 21)
      alerts = described_class.new(user.reload, now: now + GardenAlerts::WEATHER_TTL + 1)
      expect(alerts.needs_water.map(&:location_id)).to eq(%w[A3])
      expect(alerts.recent_rain_in).to eq(0.0)
    end

    it "respects a cell's custom schedule" do
      month_of_weather
      butterfly_bush("A1", 20, watering_override_days: 14)
      butterfly_bush("A2", 40, watering_override_days: 0)

      expect(described_class.new(user, now: now).needs_water.map(&:location_id)).to eq(%w[A1])
    end
  end
end
