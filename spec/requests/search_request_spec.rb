require "spec_helper"

RSpec.describe "Search Request", type: :request do
  include Rack::Test::Methods
  def app
    Backyarder
  end

  describe "GET /search/:q", :vcr do
    it "returns JSON data" do
      VCR.use_cassette("search_request") do
        get "/search/maple"
        expect(last_response).to be_ok
        response = JSON.parse(last_response.body, symbolize_names: true)
        expect(response[:data]).to be_an(Array)
        expect(response[:data].count).to be <= 10

        response[:data].each do |plant|
          expect(plant).to have_key(:id)
          expect(plant[:id]).to eq(nil)
          expect(plant).to have_key(:type)
          expect(plant[:type]).to eq("list")
          expect(plant).to have_key(:attributes)

          expect(plant[:attributes]).to have_key(:image)
          expect(plant[:attributes][:image]).to be_a String
          expect(plant[:attributes]).to have_key(:name)
          expect(plant[:attributes][:name]).to be_a String
          expect(plant[:attributes]).to have_key(:hardiness)
          expect(plant[:attributes][:hardiness]).to be_a Hash
          expect(plant[:attributes]).to have_key(:type)
          expect(plant[:attributes][:type]).to be_a String
          expect(plant[:attributes]).to have_key(:sunlight)
          expect(plant[:attributes][:sunlight]).to be_a Array
          expect(plant[:attributes]).to have_key(:plant_id)
          expect(plant[:attributes][:plant_id]).to be_a Integer
        end
      end
    end
  end
end
