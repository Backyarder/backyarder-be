require "spec_helper"

RSpec.describe "Delete Garden request", type: :request do
  let(:user) { create_user }
  let(:garden) { Garden.create!(user: user, name: "Test") }

  describe "DELETE /garden" do
    it "empties all cells with a status of 'placed'" do
      garden.cells.create!(location_id: "A1", status: :empty)
      garden.cells.create!(location_id: "A2", status: :empty)
      garden.cells.create!(location_id: "A3", status: :empty)

      garden.cells.create!(location_id: "B1", status: :placed)
      garden.cells.create!(location_id: "B2", status: :placed)
      garden.cells.create!(location_id: "B3", status: :placed)

      garden.cells.create!(location_id: "C1", status: :disabled)
      garden.cells.create!(location_id: "C2", status: :disabled)
      garden.cells.create!(location_id: "C3", status: :disabled)

      garden.cells.create!(location_id: "D1", status: :locked)
      garden.cells.create!(location_id: "D2", status: :locked)
      garden.cells.create!(location_id: "D3", status: :locked)

      expect(Cell.empty.count).to eq(3)
      expect(Cell.placed.count).to eq(3)
      expect(Cell.disabled.count).to eq(3)
      expect(Cell.locked.count).to eq(3)

      delete "/garden", nil, auth_headers(user)

      expect(last_response).to be_successful

      expect(Cell.empty.count).to eq(6)
      expect(Cell.placed.count).to eq(0)
      expect(Cell.disabled.count).to eq(3)
      expect(Cell.locked.count).to eq(3)
    end
  end
end
