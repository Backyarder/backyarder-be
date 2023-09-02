require "spec_helper"

RSpec.describe "Search Request", type: :request do
  include Rack::Test::Methods
  def app
    Backyarder
  end

  describe "GET /garden-stats" do
    it "gets a list of all garden plants" do
      cell = Cell.create!(location_id: "A1", status: 1, plant_name: "Green Leaf", image: "google.com", plant_id: 1 )
      cell = Cell.create!(location_id: "A2", status: 1, plant_name: "Green Leaf", image: "google.com", plant_id: 1 )
      cell = Cell.create!(location_id: "A3", status: 1, plant_name: "Green Leaf", image: "google.com", plant_id: 1 )

      response = get "/garden-stats"

      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)
      expect(json_response).to eq({:"Green Leaf"=>3})
    end
  end
end