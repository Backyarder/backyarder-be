require "spec_helper"

RSpec.describe "Get Garden request", type: :request do
  describe "get /garden" do
    it "returns all cell data" do
      Cell.create!(location_id: "A1", status: :empty)
      Cell.create!(location_id: "A2", status: :empty)
      Cell.create!(location_id: "A3", status: :empty)

      Cell.create!(location_id: "B1", status: :placed, plant_id: 1, image: "image_url_1", name: "Bushy Bush", watering: :Frequent)
      Cell.create!(location_id: "B2", status: :placed, plant_id: 2, image: "image_url_2", name: "Weedy Weed", watering: :Minimum)
      Cell.create!(location_id: "B3", status: :placed, plant_id: 3, image: "image_url_3", name: "Leafy Leaf", watering: :Average)

      Cell.create!(location_id: "C1", status: :disabled)
      Cell.create!(location_id: "C2", status: :disabled)
      Cell.create!(location_id: "C3", status: :disabled)

      Cell.create!(location_id: "D1", status: :locked, plant_id: 4, image: "image_url_4", name: "Mossy Moss", watering: :None)
      Cell.create!(location_id: "D2", status: :locked, plant_id: 5, image: "image_url_5", name: "Ferny Fern", watering: :None)
      Cell.create!(location_id: "D3", status: :locked, plant_id: 6, image: "image_url_6", name: "Grassy Grass", watering: :None)

      expect(Cell.empty.count).to eq(3)
      expect(Cell.placed.count).to eq(3)
      expect(Cell.disabled.count).to eq(3)
      expect(Cell.locked.count).to eq(3)

      headers = { "CONTENT_TYPE" => "application/json" }

      response = get "/garden", headers

      expect(response).to be_successful

      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response[:data].count).to eq(12)

      expect(json_response[:data][0][:attributes][:location_id]).to eq("A1")
      expect(json_response[:data][0][:attributes][:status]).to eq("empty")
      expect(json_response[:data][0][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][0][:attributes][:image]).to be_nil
      expect(json_response[:data][0][:attributes][:name]).to be_nil

      expect(json_response[:data][1][:attributes][:location_id]).to eq("A2")
      expect(json_response[:data][1][:attributes][:status]).to eq("empty")
      expect(json_response[:data][1][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][1][:attributes][:image]).to be_nil
      expect(json_response[:data][1][:attributes][:name]).to be_nil

      expect(json_response[:data][2][:attributes][:location_id]).to eq("A3")
      expect(json_response[:data][2][:attributes][:status]).to eq("empty")
      expect(json_response[:data][2][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][2][:attributes][:image]).to be_nil
      expect(json_response[:data][2][:attributes][:name]).to be_nil

      expect(json_response[:data][3][:attributes][:location_id]).to eq("B1")
      expect(json_response[:data][3][:attributes][:status]).to eq("placed")
      expect(json_response[:data][3][:attributes][:plant_id]).to eq(1)
      expect(json_response[:data][3][:attributes][:image]).to eq("image_url_1")
      expect(json_response[:data][3][:attributes][:name]).to eq("Bushy Bush")
      expect(json_response[:data][3][:attributes][:watering]).to eq("Frequent")

      expect(json_response[:data][4][:attributes][:location_id]).to eq("B2")
      expect(json_response[:data][4][:attributes][:status]).to eq("placed")
      expect(json_response[:data][4][:attributes][:plant_id]).to eq(2)
      expect(json_response[:data][4][:attributes][:image]).to eq("image_url_2")
      expect(json_response[:data][4][:attributes][:name]).to eq("Weedy Weed")
      expect(json_response[:data][4][:attributes][:watering]).to eq("Minimum")

      expect(json_response[:data][5][:attributes][:location_id]).to eq("B3")
      expect(json_response[:data][5][:attributes][:status]).to eq("placed")
      expect(json_response[:data][5][:attributes][:plant_id]).to eq(3)
      expect(json_response[:data][5][:attributes][:image]).to eq("image_url_3")
      expect(json_response[:data][5][:attributes][:name]).to eq("Leafy Leaf")
      expect(json_response[:data][5][:attributes][:watering]).to eq("Average")

      expect(json_response[:data][6][:attributes][:location_id]).to eq("C1")
      expect(json_response[:data][6][:attributes][:status]).to eq("disabled")
      expect(json_response[:data][6][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][6][:attributes][:image]).to be_nil
      expect(json_response[:data][6][:attributes][:name]).to be_nil

      expect(json_response[:data][7][:attributes][:location_id]).to eq("C2")
      expect(json_response[:data][7][:attributes][:status]).to eq("disabled")
      expect(json_response[:data][7][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][7][:attributes][:image]).to be_nil
      expect(json_response[:data][7][:attributes][:name]).to be_nil

      expect(json_response[:data][8][:attributes][:location_id]).to eq("C3")
      expect(json_response[:data][8][:attributes][:status]).to eq("disabled")
      expect(json_response[:data][8][:attributes][:plant_id]).to be_nil
      expect(json_response[:data][8][:attributes][:image]).to be_nil
      expect(json_response[:data][8][:attributes][:name]).to be_nil

      expect(json_response[:data][9][:attributes][:location_id]).to eq("D1")
      expect(json_response[:data][9][:attributes][:status]).to eq("locked")
      expect(json_response[:data][9][:attributes][:plant_id]).to eq(4)
      expect(json_response[:data][9][:attributes][:image]).to eq("image_url_4")
      expect(json_response[:data][9][:attributes][:name]).to eq("Mossy Moss")
      expect(json_response[:data][9][:attributes][:watering]).to eq("None")

      expect(json_response[:data][10][:attributes][:location_id]).to eq("D2")
      expect(json_response[:data][10][:attributes][:status]).to eq("locked")
      expect(json_response[:data][10][:attributes][:plant_id]).to eq(5)
      expect(json_response[:data][10][:attributes][:image]).to eq("image_url_5")
      expect(json_response[:data][10][:attributes][:name]).to eq("Ferny Fern")
      expect(json_response[:data][10][:attributes][:watering]).to eq("None")

      expect(json_response[:data][11][:attributes][:location_id]).to eq("D3")
      expect(json_response[:data][11][:attributes][:status]).to eq("locked")
      expect(json_response[:data][11][:attributes][:plant_id]).to eq(6)
      expect(json_response[:data][11][:attributes][:image]).to eq("image_url_6")
      expect(json_response[:data][11][:attributes][:name]).to eq("Grassy Grass")
      expect(json_response[:data][11][:attributes][:watering]).to eq("None")
    end
  end
end
