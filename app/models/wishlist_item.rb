class WishlistItem < ActiveRecord::Base
  belongs_to :user

  validates :plant_id, presence: true, uniqueness: { scope: :user_id }
end
