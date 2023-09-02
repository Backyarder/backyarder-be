require "spec_helper"

RSpec.describe "Plant details request", type: :request do
  include Rack::Test::Methods
  def app
    Backyarder
  end

  describe "DELETE /all" do
    it "empties all cells on the grid" do
      Cell.create!(location_id: "A1", status: :empty)
      Cell.create!(location_id: "A2", status: :empty)
      Cell.create!(location_id: "A3", status: :empty)

      Cell.create!(location_id: "B1", status: :placed)
      Cell.create!(location_id: "B2", status: :placed)
      Cell.create!(location_id: "B3", status: :placed)

      Cell.create!(location_id: "C1", status: :disabled)
      Cell.create!(location_id: "C2", status: :disabled)
      Cell.create!(location_id: "C3", status: :disabled)

      Cell.create!(location_id: "D1", status: :locked)
      Cell.create!(location_id: "D2", status: :locked)
      Cell.create!(location_id: "D3", status: :locked)

      expect(Cell.empty.count).to eq(3)
      expect(Cell.placed.count).to eq(3)
      expect(Cell.disabled.count).to eq(3)
      expect(Cell.locked.count).to eq(3)

      delete "/all"

      expect(last_response).to be_successful

      expect(Cell.empty.count).to eq(12)
      expect(Cell.placed.count).to eq(0)
      expect(Cell.disabled.count).to eq(0)
      expect(Cell.locked.count).to eq(0)
    end
  end
end
