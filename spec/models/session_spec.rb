require "spec_helper"

RSpec.describe Session, type: :model do
  let(:user) { User.create!(email: "s@example.com", password: "gardening1") }

  it "issues a token whose digest, not plaintext, is stored" do
    session = Session.issue!(user)

    expect(session.token).to be_a(String)
    expect(session.token.length).to be >= 32
    expect(session.token_digest).to eq(Session.digest(session.token))
    expect(session.token_digest).not_to eq(session.token)
  end

  it "authenticates a live token and rejects unknown or expired ones" do
    now = Time.now
    session = Session.issue!(user, now: now)

    expect(Session.authenticate(session.token, now: now)).to eq(session)
    expect(Session.authenticate(session.token, now: now + Session::TTL + 1)).to be_nil
    expect(Session.authenticate("not-a-token", now: now)).to be_nil
    expect(Session.authenticate(nil, now: now)).to be_nil
  end

  it "ends when destroyed (logout)" do
    session = Session.issue!(user)
    session.destroy!

    expect(Session.authenticate(session.token)).to be_nil
  end
end
