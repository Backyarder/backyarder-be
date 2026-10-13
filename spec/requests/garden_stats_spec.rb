require "spec_helper"

RSpec.describe "Garden stats request", type: :request do
  describe "GET /garden-stats" do
    it "counts placed plants using the image stored on each cell, with no Perenual calls" do
      Cell.create!(location_id: "A1", status: 1, name: "Green Leaf", image: "https://img.example/leaf.jpg", watering: "Frequent", plant_id: 1)
      Cell.create!(location_id: "A2", status: 1, name: "Green Leaf", image: "https://img.example/leaf.jpg", watering: "Average", plant_id: 1)
      Cell.create!(location_id: "A3", status: 0)

      get "/garden-stats"

      expect(last_response).to be_successful
      json_response = JSON.parse(last_response.body, symbolize_names: true)
      expect(json_response).to eq({ "Green Leaf": { count: 2, image: "https://img.example/leaf.jpg" } })
      expect(ApiUsage.count_today).to eq(0)
    end
  end
end
