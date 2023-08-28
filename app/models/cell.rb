class Cell < ActiveRecord::Base
  validates :location_id, presence: true
  validates :status, presence: true
end
