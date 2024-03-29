class Cell < ActiveRecord::Base
  validates :location_id, presence: true
  validates :status, presence: true

  enum status: { empty: 0, placed: 1, disabled: 2, locked: 3 }
  enum watering: { None: 0, Minimum: 1, Average: 2, Frequent: 3 }
  enum content_type: { Plant: "Plant", Decor: "Decor" }
end
