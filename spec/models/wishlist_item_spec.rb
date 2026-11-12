require "spec_helper"

RSpec.describe WishlistItem, type: :model do
  it "is unique per user and plant" do
    user = User.create!(email: "w@example.com", password: "gardening1")
    other = User.create!(email: "w2@example.com", password: "gardening1")
    user.wishlist_items.create!(plant_id: 7)

    expect(user.wishlist_items.build(plant_id: 7)).not_to be_valid
    expect(other.wishlist_items.build(plant_id: 7)).to be_valid
    expect(user.wishlist_items.build(plant_id: nil)).not_to be_valid
  end
end
