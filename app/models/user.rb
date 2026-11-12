require "bcrypt"
require "securerandom"

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

  # --- password reset -------------------------------------------------------

  RESET_TTL = 60 * 60 # 1 hour

  # Issues a single-use reset token and returns the plaintext (only here).
  def issue_reset_token!(now: Time.now)
    token = SecureRandom.urlsafe_base64(32)
    update_columns(reset_token_digest: Session.digest(token), reset_sent_at: now)
    token
  end

  # The user whose live reset token this is, or nil.
  def self.find_by_reset_token(token, now: Time.now)
    return nil if token.to_s.empty?

    user = find_by(reset_token_digest: Session.digest(token))
    return nil if user.nil? || user.reset_sent_at.nil? || user.reset_sent_at < now - RESET_TTL

    user
  end

  # Sets the new password, burns the token and ends every existing session.
  def reset_password!(new_password)
    self.password = new_password
    self.reset_token_digest = nil
    self.reset_sent_at = nil
    save!
    sessions.destroy_all
  end

  # Every user gets one garden for now; created lazily so signup stays cheap.
  def garden
    gardens.first || Garden.create_for!(self)
  end
end
