require "spec_helper"

RSpec.describe "GET /stats", type: :request do
  let(:day) { 24 * 60 * 60 }

  it "reports counts and dates without any personal data" do
    now = Time.now
    alice = User.create!(email: "alice@example.com", password: "gardening1", zip_code: "30501", last_digest_sent_on: now.utc.to_date)
    bob = User.create!(email: "bob@example.com", password: "gardening1", last_digest_sent_on: now.utc.to_date - 3)
    bob.update_columns(created_at: now - 30 * day)
    Session.issue!(alice)
    alice.garden.cells.find_by(location_id: "A1").update!(status: :locked, name: "Fern", plant_id: 1, content_type: "Plant", watering: :Frequent, planted_at: now - 9 * day, last_watered_at: now - 9 * day)
    alice.garden.cells.find_by(location_id: "A2").update!(status: :placed, name: "Rose", plant_id: 2, content_type: "Plant")
    bob.garden
    Garden.create!(name: "Shared garden").cells.create!(location_id: "B1", status: :locked, name: "Legacy", plant_id: 3)

    get "/stats"

    expect(last_response).to be_ok
    expect(last_response.headers["Cache-Control"]).to include("no-store")
    body = JSON.parse(last_response.body, symbolize_names: true)
    expect(body[:accounts]).to include(total: 2, new_last_7_days: 1, with_zip_code: 1, active_last_7_days: 1, last_signup_on: now.utc.to_date.iso8601)
    expect(body[:gardens]).to eq(with_plants: 1, items_placed: 1, items_planted: 1, plants_needing_water: 1)
    expect(body[:digest]).to eq(sent_today: 1, last_sent_on: now.utc.to_date.iso8601, users_ever_emailed: 2)
    expect(body[:plant_data]).to include(catalogue_done: false, perenual_calls_today: 0)
    expect(last_response.body).not_to include("example.com", "Fern", "Rose")
  end

  it "works on an empty database" do
    get "/stats"

    body = JSON.parse(last_response.body, symbolize_names: true)
    expect(body[:accounts]).to include(total: 0, last_signup_on: nil, last_login_on: nil)
    expect(body[:digest]).to include(sent_today: 0, last_sent_on: nil)
  end
end
