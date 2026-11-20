require "spec_helper"

RSpec.describe "Search Request", type: :request do
  let(:user) { create_user }
  let(:garden) { Garden.create!(user: user, name: "Test") }

  describe "PATCH /cell" do
    it "takes a proper json payload and returns a proper json payload" do
      cell = garden.cells.create!(location_id: "A1", status: 0)
      cell_params = { name: "Green Leaf", location_id: "A1", image: "google.com", watering:"Frequent", status: 1, plant_id: 1 }
      response = patch "/cell", JSON.generate(cell_params), json_headers(user)
      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)
      expected = {
        "data": {
          "id": "1",
          "type": "cell",
          "attributes": {
            "content_type": nil,
            "image": "google.com",
            "name": "Green Leaf",
            "location_id": "A1",
            "status": "placed",
            "watering": "Frequent",
            "plant_id": 1,
            "updated_at": cell.updated_at.strftime("%m/%d/%Y %k:%M").to_s,
            "planted_at": nil,
            "last_watered_at": nil,
            "next_water_at": nil,
            "needs_water": false,
            "watering_days": 2,
            "watering_reason": "Based on its frequent watering needs",
            "watering_source": "auto",
            "watering_rain_resets": true,
            "watering_override_days": nil
          }
        }
      }
      expect(json_response).to eq(expected)
    end

    it "records planting and watering times when a cell is locked" do
      garden.cells.create!(location_id: "A1", status: :placed, plant_id: 1, name: "Fern", content_type: "Plant", watering: :Frequent)
      cell_params = { name: "Fern", content_type: "Plant", location_id: "A1", image: "img", status: 3, watering: "Frequent", plant_id: 1 }

      response = patch "/cell", JSON.generate(cell_params), json_headers(user)

      expect(response).to be_successful
      attrs = JSON.parse(response.body, symbolize_names: true)[:data][:attributes]
      expect(attrs[:status]).to eq("locked")
      expect(attrs[:planted_at]).not_to be_nil
      expect(attrs[:last_watered_at]).to eq(attrs[:planted_at])
      expect(attrs[:needs_water]).to be(false)
      expect(Time.iso8601(attrs[:next_water_at])).to be_within(60).of(Time.now + 2 * 24 * 60 * 60)
    end

    it "treats re-locking as a watering but keeps the original planting date" do
      long_ago = Time.now - 10 * 24 * 60 * 60
      garden.cells.create!(location_id: "A1", status: :locked, plant_id: 1, name: "Fern", content_type: "Plant", watering: :Frequent, planted_at: long_ago, last_watered_at: long_ago)
      cell_params = { name: "Fern", content_type: "Plant", location_id: "A1", image: "img", status: 3, watering: "Frequent", plant_id: 1 }

      patch "/cell", JSON.generate(cell_params), json_headers(user)

      cell = Cell.find_by(location_id: "A1")
      expect(cell.planted_at).to be_within(1).of(long_ago)
      expect(cell.last_watered_at).to be_within(60).of(Time.now)
      expect(cell.needs_water?).to be(false)
    end

    it "waters a cell with the water action" do
      long_ago = Time.now - 10 * 24 * 60 * 60
      garden.cells.create!(location_id: "A1", status: :locked, plant_id: 1, name: "Fern", content_type: "Plant", watering: :Average, planted_at: long_ago, last_watered_at: long_ago)

      response = patch "/cell", JSON.generate({ action: "water", location_id: "A1" }), json_headers(user)

      expect(response).to be_successful
      attrs = JSON.parse(response.body, symbolize_names: true)[:data][:attributes]
      expect(attrs[:status]).to eq("locked")
      expect(attrs[:needs_water]).to be(false)
      expect(Time.iso8601(attrs[:last_watered_at])).to be_within(60).of(Time.now)
    end

    it "reports needs_water for an overdue plant" do
      long_ago = Time.now - 10 * 24 * 60 * 60
      garden.cells.create!(location_id: "A1", status: :locked, plant_id: 1, name: "Fern", content_type: "Plant", watering: :Average, planted_at: long_ago, last_watered_at: long_ago)

      response = get "/garden", nil, auth_headers(user)

      attrs = JSON.parse(response.body, symbolize_names: true)[:data][0][:attributes]
      expect(attrs[:needs_water]).to be(true)
    end

    it "removes the plant from the cell and sets the status to empty" do
      cell = garden.cells.create!(location_id: "A1", status: 1, plant_id: 1, image: "image_url", watering:"Average", name: "Pretty Flower")

      cell_params = { action: "remove_plant", location_id: "A1" }

      response = patch "/cell", JSON.generate(cell_params), json_headers(user)

      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response[:data][:attributes][:status]).to eq("empty")
      expect(json_response[:data][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][:attributes][:image]).to be_nil
      expect(json_response[:data][:attributes][:watering]).to be_nil
      expect(json_response[:data][:attributes][:name]).to be_nil
      expect(json_response[:data][:attributes][:content_type]).to be_nil
      expect(json_response[:data][:attributes][:planted_at]).to be_nil
      expect(json_response[:data][:attributes][:last_watered_at]).to be_nil
    end

    it "disables the cell and sets the status to disabled" do
      cell = garden.cells.create!(location_id: "A1", status: :empty)

      cell_params = { action: "disable_cell", location_id: "A1" }

      response = patch "/cell", JSON.generate(cell_params), json_headers(user)

      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response[:data][:attributes][:status]).to eq("disabled")
    end
  end

  describe "PATCH /cell set_watering" do
    let(:day) { 24 * 60 * 60 }

    before do
      PlantDetail.create!(plant_id: 900_483, common_name: "butterfly bush",
                          summary: JSON.generate(type: "Deciduous shrub", cycle: "Perennial", watering: "Minimum", drought_tolerant: true, collection: "trees"))
      garden.cells.create!(location_id: "A1", status: :locked, plant_id: 900_483, name: "butterfly bush", content_type: "Plant",
                           watering: :Minimum, planted_at: Time.now - 200 * day, last_watered_at: Time.now - 20 * day)
    end

    def set_watering(days, extra = {})
      patch "/cell", JSON.generate({ action: "set_watering", location_id: "A1", garden_id: garden.id, days: days }.merge(extra)), json_headers(user)
    end

    it "starts on the automatic plan" do
      get "/garden?garden_id=#{garden.id}", nil, json_headers(user)
      attrs = JSON.parse(last_response.body, symbolize_names: true)[:data].first[:attributes]
      expect(attrs).to include(watering_days: 28, watering_source: "auto", watering_override_days: nil, needs_water: false,
                               watering_reason: "Established and drought tolerant: only during long dry spells")
    end

    it "sets a custom number of days and recomputes the due date" do
      response = set_watering(14)

      expect(response.status).to eq(200)
      attrs = JSON.parse(response.body, symbolize_names: true)[:data][:attributes]
      expect(attrs).to include(watering_days: 14, watering_source: "custom", watering_override_days: 14, needs_water: true)
      expect(Cell.find_by(location_id: "A1").watering_override_days).to eq(14)
    end

    it "turns reminders off with 0 and goes back to automatic with null" do
      attrs = JSON.parse(set_watering(0).body, symbolize_names: true)[:data][:attributes]
      expect(attrs).to include(watering_days: nil, watering_override_days: 0, next_water_at: nil, needs_water: false)

      attrs = JSON.parse(set_watering(nil).body, symbolize_names: true)[:data][:attributes]
      expect(attrs).to include(watering_days: 28, watering_override_days: nil, watering_source: "auto")
    end

    it "rejects days outside 0..60" do
      [61, -2, "often", 1.5].each do |days|
        response = set_watering(days)
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)["error"]).to include("0 to 60")
      end
      expect(Cell.find_by(location_id: "A1").watering_override_days).to be_nil
    end

    it "forgets the custom schedule when the plant is removed" do
      set_watering(3)
      patch "/cell", JSON.generate({ action: "remove_plant", location_id: "A1", garden_id: garden.id }), json_headers(user)
      expect(Cell.find_by(location_id: "A1").watering_override_days).to be_nil
    end
  end
end
