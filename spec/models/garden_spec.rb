require "spec_helper"

RSpec.describe Garden, type: :model do
  let(:user) { User.create!(email: "g@example.com", password: "gardening1") }

  it "creates a garden with 100 empty cells A1 through J10" do
    garden = Garden.create_for!(user)

    expect(garden.user).to eq(user)
    expect(garden.cells.count).to eq(100)
    expect(garden.cells.pluck(:location_id)).to include("A1", "A10", "J1", "J10")
    expect(garden.cells.where(status: :empty).count).to eq(100)
  end

  it "seeds idempotently, filling in only missing cells" do
    garden = Garden.create!(user: user, name: "Test")
    garden.cells.create!(location_id: "B2", status: :locked, name: "Fern", content_type: "Plant")

    expect(garden.seed_cells!).to eq(100)
    expect(garden.seed_cells!).to eq(100)
    expect(garden.cells.find_by(location_id: "B2").name).to eq("Fern")
  end

  it "does not allow two cells at the same location in one garden" do
    garden = Garden.create_for!(user)

    expect { garden.cells.create!(location_id: "A1", status: :empty) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows a legacy garden with no user" do
    expect(Garden.new(name: "Shared garden")).to be_valid
  end
end
