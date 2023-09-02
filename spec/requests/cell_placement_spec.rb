require "spec_helper"

RSpec.describe "Search Request", type: :request do
  include Rack::Test::Methods
  def app
    Backyarder
  end

  describe "PATCH /cell" do
    it "takes a proper json payload and returns a proper json payload" do
      cell = Cell.create!(location_id: "A1", status: 0)
      cell_params = { plant_name: "Green Leaf", location_id: "A1", image: "google.com", status: 1, plant_id: 1 }

      headers = { "CONTENT_TYPE" => "application/json" }
      response = patch "/cell", JSON.generate(cell_params)
      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)
      expected = {
        "data": {
          "id": "1",require "spec_helper"

RSpec.describe "Search Request", type: :request do
  include Rack::Test::Methods
  def app
    Backyarder
  end

  describe "PATCH /cell" do
    it "takes a proper json payload and returns a proper json payload" do
      cell = Cell.create!(location_id: "A1", status: 0)
      cell_params = { plant_name: "Green Leaf", location_id: "A1", image: "google.com", status: 1, plant_id: 1 }

      headers = { "CONTENT_TYPE" => "application/json" }
      response = patch "/cell", JSON.generate(cell_params)
      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)
      expected = {
        "data": {
          "id": "1",
          "type": "cell",
          "attributes": {
            "image": "google.com",
            "plant_name": "Green Leaf",
            "location_id": "A1",
            "status": "placed",
            "plant_id": 1,
            "updated_at": cell.updated_at.strftime("%m/%d/%Y %k:%M").to_s
          }
        }
      }
      expect(json_response).to eq(expected)
    end
          "type": "cell",
          "attributes": {
            "image": "google.com",
            "plant_name": "Green Leaf",
            "location_id": "A1",
            "status": "placed",
            "plant_id": 1,
            "updated_at": cell.updated_at.strftime("%m/%d/%Y %k:%M").to_s
          }
        }
      }
      expect(json_response).to eq(expected)
    end

    it "removes the plant from the cell and sets the status to empty" do
      cell = Cell.create!(location_id: "A1", status: 1, plant_id: 1, image: "image_url", plant_name: "Pretty Flower")

      cell_params = { action: "remove_plant", location_id: "A1" }
      headers = { "CONTENT_TYPE" => "application/json" }

      response = patch "/cell", JSON.generate(cell_params), headers

      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response[:data][:attributes][:status]).to eq("empty")
      expect(json_response[:data][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][:attributes][:image]).to be_nil
      expect(json_response[:data][:attributes][:plant_name]).to be_nil
    end

    it "disables the cell and sets the status to disabled" do
      cell = Cell.create!(location_id: "A1", status: :empty)

      cell_params = { action: "disable_cell", location_id: "A1" }
      headers = { "CONTENT_TYPE" => "application/json" }

      response = patch "/cell", JSON.generate(cell_params), headers

      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response[:data][:attributes][:status]).to eq("disabled")
    end
  end
end
