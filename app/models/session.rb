require "digest"
require "securerandom"

# A login session. The plaintext token is handed to the client once (in a
# cookie or header) and only its digest is stored.
class Session < ActiveRecord::Base
  TTL = 30 * 24 * 60 * 60 # 30 days

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  attr_accessor :token

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # Creates a session and returns it with #token populated (this is the only
  # time the plaintext token is available).
  def self.issue!(user, now: Time.now)
    token = SecureRandom.urlsafe_base64(32)
    session = create!(user: user, token_digest: digest(token), expires_at: now + TTL)
    session.token = token
    session
  end

  # Returns the live session for a token, or nil if unknown or expired.
  def self.authenticate(token, now: Time.now)
    return nil if token.to_s.empty?

    session = find_by(token_digest: digest(token))
    return nil if session.nil? || session.expired?(now)

    session
  end

  def expired?(now = Time.now)
    expires_at <= now
  end
end
