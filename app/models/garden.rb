# A plot: a grid of cells, rows lettered from A and columns numbered from 1
# (A1 through J10 for the default 10 x 10).
class Garden < ActiveRecord::Base
  MAX_SIDE = 15
  ROW_LETTERS = ("A".."Z").first(MAX_SIDE).freeze

  belongs_to :user, optional: true # nil = the legacy shared garden
  has_many :cells, dependent: :destroy

  MAX_PER_USER = 12
  MAX_NAME = 40

  before_validation { self.name = name.to_s.strip }
  validates :name, presence: true, length: { maximum: MAX_NAME }
  validates :rows, :cols, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_SIDE }

  scope :ordered, -> { order(:position, :id) }

  def outdoor?
    !indoor?
  end

  # The pre-accounts garden (no user). The first person to sign up inherits
  # it so the plants already in the ground are not lost; returns nil if there
  # is nothing to claim.
  def self.claim_shared!(user)
    shared = where(user_id: nil).order(:id).first
    return nil unless shared && user.gardens.none?

    shared.update!(user: user, name: "My Garden")
    shared
  end

  def self.create_for!(user, name: "My Garden", indoor: false, rows: 10, cols: 10)
    transaction do
      position = (user.gardens.maximum(:position) || -1) + 1
      garden = create!(user: user, name: name, indoor: indoor, position: position, rows: rows, cols: cols)
      garden.seed_cells!
      garden
    end
  end

  def location_ids
    ROW_LETTERS.first(rows).product((1..cols).to_a).map { |row, col| "#{row}#{col}" }
  end

  # Idempotent: creates any missing cells as empty, leaves existing ones alone.
  def seed_cells!
    existing = cells.pluck(:location_id)
    (location_ids - existing).each do |location_id|
      cells.create!(location_id: location_id, status: :empty)
    end
    cells.count
  end
end
