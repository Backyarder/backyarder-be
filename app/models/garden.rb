# A 10x10 grid of cells, A1 through J10.
class Garden < ActiveRecord::Base
  ROWS = ("A".."J").to_a.freeze
  COLUMNS = (1..10).to_a.freeze
  LOCATION_IDS = ROWS.product(COLUMNS).map { |row, col| "#{row}#{col}" }.freeze

  belongs_to :user, optional: true # nil = the legacy shared garden
  has_many :cells, dependent: :destroy

  MAX_PER_USER = 12
  MAX_NAME = 40

  before_validation { self.name = name.to_s.strip }
  validates :name, presence: true, length: { maximum: MAX_NAME }

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

  def self.create_for!(user, name: "My Garden", indoor: false)
    transaction do
      position = (user.gardens.maximum(:position) || -1) + 1
      garden = create!(user: user, name: name, indoor: indoor, position: position)
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
