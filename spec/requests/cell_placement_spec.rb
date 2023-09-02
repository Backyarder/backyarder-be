require "spec_helper"

RSpec.describe "Search Request", type: :request do
  include Rack::Test::Methods
  def app
    Backyarder
  end

  describe "PATCH /cell" do
    it "takes a proper json payload and returns a proper json payload" do
      cell = Cell.create!(location_id: "A1", status: 0)
      cell_params = { plant_name: "Green Leaf", location_id: "A1", image: "google.com", status: "1", plant_id: "1" }

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
                "status": 1,
                "plant_id": 1,
                "updated_at": "#{cell.updated_at.strftime("%m/%d/%Y %k:%M")}"
            }
        }
    }
      expect(json_response).to eq(expected)
    end
  end
end
