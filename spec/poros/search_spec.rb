require "spec_helper"

RSpec.describe Search, type: :poro do
  describe "initialize" do
    it "sets the attributes correctly" do
      data = {
        species_id: 1,
        common_name: "Sample Plant",
        type: "Sample Type"
      }

      search = Search.new(data)

      expect(search.sunlight).to be_nil
      expect(search.hardiness).to be_nil
      expect(search.watering).to be_nil
      expect(search.plant_id).to eq(1)
      expect(search.image).to be_nil
      expect(search.name).to eq("Sample Plant")
      expect(search.type).to eq("Sample Type")
      expect(search.id).to be_nil
    end
  end
end
