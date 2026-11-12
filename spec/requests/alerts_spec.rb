require "spec_helper"

RSpec.describe "Alerts", type: :request do
  let(:day) { 24 * 60 * 60 }

  before { stub_request(:get, %r{api\.open-meteo\.com}).to_return(status: 500, body: "") }

  it "GET /alerts reports the signed-in user's due plants" do
    user = create_user
    user.garden.cells.find_by(location_id: "C3").update!(status: :locked, name: "Fern", plant_id: 1, content_type: "Plant", watering: :Frequent, planted_at: Time.now - 9 * day, last_watered_at: Time.now - 9 * day)

    get "/alerts", nil, auth_headers(user)

    expect(last_response).to be_ok
    body = JSON.parse(last_response.body, symbolize_names: true)
    expect(body[:needs_water].map { |c| c[:location_id] }).to eq(["C3"])
    expect(body[:weather_available]).to be(false)

    get "/alerts"
    expect(last_response.status).to eq(401)
  end

  it "POST /alerts/digest needs the cron secret and reports a dry run" do
    user = create_user
    user.garden.cells.find_by(location_id: "C3").update!(status: :locked, name: "Fern", plant_id: 1, content_type: "Plant", watering: :Frequent, planted_at: Time.now - 9 * day, last_watered_at: Time.now - 9 * day)

    ENV["CRON_SECRET"] = "s3cret"
    post "/alerts/digest?dry_run=1"
    expect(last_response.status).to eq(401)

    post "/alerts/digest?dry_run=1", nil, { "HTTP_X_CRON_SECRET" => "s3cret" }
    expect(last_response).to be_ok
    expect(JSON.parse(last_response.body, symbolize_names: true)).to eq(sent: [user.email], skipped: 0, dry_run: true)

    post "/alerts/digest?secret=s3cret"
    expect(last_response.status).to eq(503)
    expect(JSON.parse(last_response.body)["error"]).to include("SMTP_HOST")
  ensure
    ENV.delete("CRON_SECRET")
  end

  it "POST /alerts/digest is off until CRON_SECRET is set" do
    ENV.delete("CRON_SECRET")
    post "/alerts/digest?secret=anything"
    expect(last_response.status).to eq(503)
  end
end
