# A 10x10 grid of cells, A1 through J10.
class Garden < ActiveRecord::Base
  ROWS = ("A".."J").to_a.freeze
  COLUMNS = (1..10).to_a.freeze
  LOCATION_IDS = ROWS.product(COLUMNS).map { |row, col| "#{row}#{col}" }.freeze

  belongs_to :user, optional: true # nil = the legacy shared garden
  has_many :cells, dependent: :destroy

  validates :name, presence: true

  def self.create_for!(user, name: "My Garden")
    transaction do
      garden = create!(user: user, name: name)
      garden.seed_cells!
      garden
    end
  end

  # Idempotent: creates any missing cells as empty, leaves existing ones alone.
  def seed_cells!
    existing = cells.pluck(:location_id)
    (LOCATION_IDS - existing).each do |location_id|
      cells.create!(location_id: location_id, status: :empty)
    end
    cells.count
  end
end
