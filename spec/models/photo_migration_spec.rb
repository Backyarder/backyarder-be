require "spec_helper"
require_relative "../../db/migrate/20261121090100_use_photos_for_placed_built_ins"

RSpec.describe UsePhotosForPlacedBuiltIns do
  it "points placed built-ins at their photos and leaves everything else alone" do
    garden = Garden.create_for!(create_user)
    cell = ->(id) { garden.cells.find_by(location_id: id) }
    cell.call("A1").update!(status: :locked, plant_id: 900_001, name: "tomato", image: "/images/kitchen/tomato.svg")
    cell.call("A2").update!(status: :placed, plant_id: 2692, name: "coneflower", image: "/images/plants/274.jpg")
    cell.call("A3").update!(status: :locked, plant_id: 900_002, name: "basil", image: "/images/plants/900002.jpg")

    ActiveRecord::Migration.suppress_messages { described_class.new.up }

    expect(cell.call("A1").image).to eq("/images/plants/900001.jpg")
    expect(cell.call("A2").image).to eq("/images/plants/274.jpg")
    expect(cell.call("A3").image).to eq("/images/plants/900002.jpg")
    expect { described_class.new.down }.not_to raise_error
  end
end
