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

  describe "watering enums" do
    it "should have a watering None" do
      cell = Cell.create!(location_id: "A1", status: :placed, watering: :None)
      expect(cell.watering).to eq("None")
    end

    it "should have a watering Minimum" do
      cell = Cell.create!(location_id: "A1", status: :placed, watering: :Minimum)
      expect(cell.watering).to eq("Minimum")
    end

    it "should have a watering Average" do
      cell = Cell.create!(location_id: "A1", status: :placed, watering: :Average)
      expect(cell.watering).to eq("Average")
    end

    it "should have a watering Frequent" do
      cell = Cell.create!(location_id: "A1", status: :placed, watering: :Frequent)
      expect(cell.watering).to eq("Frequent")
    end
  end
end

RSpec.describe Cell, "watering schedule" do
  let(:now) { Time.utc(2026, 11, 12, 12, 0, 0) }
  let(:day) { 24 * 60 * 60 }

  def planted_cell(watering:, content_type: "Plant", status: :locked)
    Cell.create!(location_id: "A1", status: status, name: "Thing", plant_id: 1, content_type: content_type, watering: watering)
  end

  it "is not on a schedule until the plant is in the ground" do
    cell = planted_cell(watering: :Frequent, status: :placed)
    cell.update!(last_watered_at: now - 30 * day)

    expect(cell.tracks_watering?).to be(false)
    expect(cell.next_water_at).to be_nil
    expect(cell.needs_water?(now)).to be(false)
  end

  it "never needs water for decor or plants marked None" do
    expect(planted_cell(watering: :None).tap { |c| c.update!(planted_at: now - 99 * day) }.needs_water?(now)).to be(false)
    expect(planted_cell(watering: :Frequent, content_type: "Decor").tap { |c| c.update!(planted_at: now - 99 * day) }.needs_water?(now)).to be(false)
  end

  it "is due one interval after the last watering" do
    cell = planted_cell(watering: :Average)
    cell.plant!(now)

    expect(cell.planted_at).to eq(now)
    expect(cell.last_watered_at).to eq(now)
    expect(cell.next_water_at).to eq(now + Cell::WATERING_INTERVAL_DAYS["Average"] * day)
    expect(cell.needs_water?(now + 4 * day)).to be(false)
    expect(cell.needs_water?(now + 5 * day)).to be(true)
  end

  it "resets the clock when watered and keeps the planting date" do
    cell = planted_cell(watering: :Frequent)
    cell.plant!(now)
    cell.water!(now + 3 * day)

    expect(cell.planted_at).to eq(now)
    expect(cell.last_watered_at).to eq(now + 3 * day)
    expect(cell.needs_water?(now + 4 * day)).to be(false)
    expect(cell.needs_water?(now + 5 * day)).to be(true)
  end

  it "falls back to the planting date when never explicitly watered" do
    cell = planted_cell(watering: :Minimum)
    cell.update!(planted_at: now - 11 * day)

    expect(cell.needs_water?(now)).to be(true)
  end

  it "forgets its history when cleared" do
    cell = planted_cell(watering: :Frequent)
    cell.plant!(now)
    cell.clear!

    expect(cell).to be_empty
    expect(cell.name).to be_nil
    expect(cell.planted_at).to be_nil
    expect(cell.last_watered_at).to be_nil
    expect(cell.needs_water?(now + 99 * day)).to be(false)
  end
end
