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

  it "writes a readable message only when there is something to say" do
    stub_weather(rain: [0.4, 0.2, 0, 0, 0])
    expect(described_class.new(user, now: now).message).to be_nil

    plant("B2", :Frequent, 3)
    message = described_class.new(user.reload, now: now).message
    expect(message).to include("Plants due for water (1)", "Plant B2 in B2", "skip these", "https://backyarder.vercel.app")
  end
end
