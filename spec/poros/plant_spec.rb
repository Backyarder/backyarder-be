require "spec_helper"

RSpec.describe Plant, type: :poro do
  describe "initialize" do
    it "sets the attributes correctly" do
      plant_data = {
        id: 1,
        common_name: "Maple"
      }

      plant = Plant.new(plant_data)

      expect(plant.id).to be_nil
      expect(plant.plant_id).to eq(1)
      expect(plant.name).to eq("Maple")
      expect(plant.sunlight).to be_nil
      expect(plant.hardiness).to be_nil
      expect(plant.image).to be_nil
      expect(plant.type).to be_nil
    end
  end
end
