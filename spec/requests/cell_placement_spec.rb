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
            "needs_water": false
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
end
