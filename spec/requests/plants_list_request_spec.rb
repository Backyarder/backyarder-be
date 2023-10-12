require "spec_helper"

RSpec.describe "Plant list request", type: :request do
  describe "GET /plants" do
    it "returns JSON data" do
      get "/plants"
      expect(last_response).to be_ok
      response = JSON.parse(last_response.body, symbolize_names: true)

      expect(response[:data][0]).to have_key(:id)
      expect(response[:data][0][:id]).to eq(nil)
      expect(response[:data][0]).to have_key(:type)
      expect(response[:data][0][:type]).to eq("list")
      expect(response[:data][0]).to have_key(:attributes)

      expect(response[:data][0][:attributes]).to have_key(:image)
      expect(response[:data][0][:attributes][:image]).to be_a String
      expect(response[:data][0][:attributes]).to have_key(:plant_name)
      expect(response[:data][0][:attributes][:plant_name]).to be_a String
      expect(response[:data][0][:attributes]).to have_key(:hardiness)
      expect(response[:data][0][:attributes][:hardiness]).to be_a Hash
      expect(response[:data][0][:attributes]).to have_key(:watering)
      expect(response[:data][0][:attributes][:watering]).to be_a String
      expect(response[:data][0][:attributes]).to have_key(:type)
      expect(response[:data][0][:attributes][:type]).to be_a String
      expect(response[:data][0][:attributes]).to have_key(:sunlight)
      expect(response[:data][0][:attributes][:sunlight]).to be_a Array
      expect(response[:data][0][:attributes]).to have_key(:plant_id)
      expect(response[:data][0][:attributes][:plant_id]).to be_a Integer
    end
  end
end
