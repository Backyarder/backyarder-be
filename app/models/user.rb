require "bcrypt"

class User < ActiveRecord::Base
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  MIN_PASSWORD_LENGTH = 8

  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :gardens, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy

  before_validation { self.email = email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: EMAIL_FORMAT }
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true
  validates :zip_code, format: { with: /\A\d{5}\z/ }, allow_blank: true

  # Case-insensitive lookup; returns nil unless the password matches.
  def self.authenticate(email, password)
    find_by(email: email.to_s.strip.downcase)&.authenticate(password) || nil
  end

  # Every user gets one garden for now; created lazily so signup stays cheap.
  def garden
    gardens.first || Garden.create_for!(self)
  end
end
