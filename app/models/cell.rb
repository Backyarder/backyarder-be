class Cell < ActiveRecord::Base
  validates :location_id, presence: true
  validates :status, presence: true

  enum status: { empty: 0, placed: 1, disabled: 2, locked: 3 }
end
