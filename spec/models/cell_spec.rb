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

  describe "status enums" do
    it "should have a status empty" do
      cell = Cell.create!(location_id: "A1", status: :empty)
      expect(cell.empty?).to be_truthy
    end

    it "should have a status placed" do
      cell = Cell.create!(location_id: "A1", status: :placed)
      expect(cell.placed?).to be_truthy
    end

    it "should have a status disabled" do
      cell = Cell.create!(location_id: "A1", status: :disabled)
      expect(cell.disabled?).to be_truthy
    end

    it "should have a status locked" do
      cell = Cell.create!(location_id: "A1", status: :locked)
      expect(cell.locked?).to be_truthy
    end
  end
end
