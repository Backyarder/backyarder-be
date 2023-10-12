require "spec_helper"

RSpec.describe "Search Request", type: :request do
  describe "GET /garden-stats" do
    it "gets a list of all garden plants" do
      VCR.use_cassette("gardentstats-1") do
        VCR.use_cassette("gardentstats-2") do
          cell = Cell.create!(location_id: "A1", status: 1, name: "Green Leaf", image: "google.com", watering: "Frequent", plant_id: 1)
          cell = Cell.create!(location_id: "A2", status: 1, name: "Green Leaf", image: "google.com", watering: "Average", plant_id: 1)

          response = get "/garden-stats"

          expect(response).to be_successful
          json_response = JSON.parse(response.body, symbolize_names: true)
          expect(json_response).to eq({ :"Green Leaf" => { :count=>2, :image=>"https://perenual.com/storage/species_image/1_abies_alba/small/1536px-Abies_alba_SkalitC3A9.jpg" } })
        end
      end
    end
  end
end
