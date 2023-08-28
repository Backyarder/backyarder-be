require "spec_helper"

RSpec.describe Cell, type: :model do
  describe "Validations" do
    it "is valid as long as location_id and status are given" do
      cell = Cell.new(location_id: "A1", status: 0)

      expect(cell).to be_valid
    end

    it "is invalid without a location_id" do
      cell = Cell.new(status: 0)

      expect(cell).to_not be_valid
    end

    it "is invalid without a status" do
      cell = Cell.new(location_id: "A1")

      expect(cell).to_not be_valid
    end
  end
end
