require "spec_helper"

RSpec.describe User, type: :model do
  it "normalizes the email and hashes the password" do
    user = User.create!(email: "  Friend@Example.com ", password: "gardening1")

    expect(user.email).to eq("friend@example.com")
    expect(user.password_digest).not_to eq("gardening1")
    expect(user.authenticate("gardening1")).to eq(user)
    expect(user.authenticate("wrong")).to be_falsey
  end

  it "requires a unique, well-formed email" do
    User.create!(email: "a@example.com", password: "gardening1")

    expect(User.new(email: "A@example.com", password: "gardening1")).not_to be_valid
    expect(User.new(email: "not-an-email", password: "gardening1")).not_to be_valid
    expect(User.new(email: "", password: "gardening1")).not_to be_valid
  end

  it "requires a password of at least #{User::MIN_PASSWORD_LENGTH} characters" do
    expect(User.new(email: "b@example.com", password: "short")).not_to be_valid
    expect(User.new(email: "b@example.com", password: "longenough")).to be_valid
  end

  it "accepts a five digit zip code or none" do
    expect(User.new(email: "c@example.com", password: "gardening1", zip_code: "30501")).to be_valid
    expect(User.new(email: "c@example.com", password: "gardening1", zip_code: "")).to be_valid
    expect(User.new(email: "c@example.com", password: "gardening1", zip_code: "3050")).not_to be_valid
  end

  describe ".authenticate" do
    it "finds the user case-insensitively and checks the password" do
      user = User.create!(email: "d@example.com", password: "gardening1")

      expect(User.authenticate("D@EXAMPLE.COM", "gardening1")).to eq(user)
      expect(User.authenticate("d@example.com", "nope")).to be_nil
      expect(User.authenticate("nobody@example.com", "gardening1")).to be_nil
    end
  end

  describe "#garden" do
    it "creates a seeded garden on first access and reuses it after" do
      user = User.create!(email: "e@example.com", password: "gardening1")

      garden = user.garden
      expect(garden.cells.count).to eq(100)
      expect(user.garden).to eq(garden)
      expect(Garden.count).to eq(1)
    end
  end

  it "removes sessions, gardens and wishlist items with the user" do
    user = User.create!(email: "f@example.com", password: "gardening1")
    Session.issue!(user)
    user.garden
    user.wishlist_items.create!(plant_id: 42)

    user.destroy!

    expect(Session.count).to eq(0)
    expect(Garden.count).to eq(0)
    expect(Cell.count).to eq(0)
    expect(WishlistItem.count).to eq(0)
  end
end
