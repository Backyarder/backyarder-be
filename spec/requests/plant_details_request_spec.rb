require "spec_helper"

RSpec.describe "Plant details request", type: :request do
  describe "GET /plants/:id" do
    it "returns JSON data" do
      VCR.use_cassette("plant_show") do
        get "/plants/225"

        expect(last_response).to be_ok
        response = JSON.parse(last_response.body, symbolize_names: true)
        expect(response[:data]).to have_key(:id)
        expect(response[:data][:id]).to eq(nil)
        expect(response[:data]).to have_key(:type)
        expect(response[:data][:type]).to eq("detail")
        expect(response[:data]).to have_key(:attributes)
        expect(response[:data][:attributes]).to have_key(:plant_id)
        expect(response[:data][:attributes][:plant_id]).to eq(225)
        expect(response[:data][:attributes]).to have_key(:image)
        expect(response[:data][:attributes][:image]).to be_a String
        expect(response[:data][:attributes]).to have_key(:name)
        expect(response[:data][:attributes][:name]).to be_a String
        expect(response[:data][:attributes]).to have_key(:scientific_name)
        expect(response[:data][:attributes][:scientific_name]).to be_an Array
        expect(response[:data][:attributes][:scientific_name][0]).to be_a String
        expect(response[:data][:attributes]).to have_key(:type)
        expect(response[:data][:attributes][:type]).to be_a String
        expect(response[:data][:attributes]).to have_key(:leaf_color)
        expect(response[:data][:attributes][:leaf_color]).to be_an Array
        expect(response[:data][:attributes]).to have_key(:cycle)
        expect(response[:data][:attributes][:cycle]).to be_a String
        expect(response[:data][:attributes]).to have_key(:watering)
        expect(response[:data][:attributes][:watering]).to be_a String
        expect(response[:data][:attributes]).to have_key(:sunlight)
        expect(response[:data][:attributes][:sunlight]).to be_a Array
        expect(response[:data][:attributes]).to have_key(:hardiness)
        expect(response[:data][:attributes][:hardiness]).to be_a Hash
        expect(response[:data][:attributes]).to have_key(:pruning_month)
        expect(response[:data][:attributes][:pruning_month]).to be_a Array
        expect(response[:data][:attributes]).to have_key(:attracts)
        expect(response[:data][:attributes][:attracts]).to be_a Array
        expect(response[:data][:attributes]).to have_key(:flowering_season)
        expect(response[:data][:attributes][:flowering_season]).to be_a Array
        expect(response[:data][:attributes]).to have_key(:edible_fruit)
        expect(response[:data][:attributes][:edible_fruit]).to be(true).or(be(false))
        expect(response[:data][:attributes]).to have_key(:maintenance)
        expect(response[:data][:attributes][:maintenance]).to be_a String
        expect(response[:data][:attributes]).to have_key(:poisonous_to_pets)
        expect(response[:data][:attributes][:poisonous_to_pets]).to be(true).or(be(false))
        expect(response[:data][:attributes]).to have_key(:drought_tolerant)
        expect(response[:data][:attributes][:drought_tolerant]).to be(true).or(be(false))
        expect(response[:data][:attributes]).to have_key(:invasive)
        expect(response[:data][:attributes][:invasive]).to be(true).or(be(false))
        expect(response[:data][:attributes]).to have_key(:indoor)
        expect(response[:data][:attributes][:indoor]).to be(true).or(be(false))
        expect(response[:data][:attributes]).to have_key(:section)
        expect(response[:data][:attributes][:section]).to be_a Array
        expect(response[:data][:attributes][:section][0]).to have_key(:id)
        expect(response[:data][:attributes][:section][0][:id]).to be_a Integer
        expect(response[:data][:attributes][:section][0]).to have_key(:type)
        expect(response[:data][:attributes][:section][0][:type]).to be_a String
        expect(response[:data][:attributes][:section][0]).to have_key(:description)
        expect(response[:data][:attributes][:section][0][:description]).to be_a String
      end
    end
  end
end
