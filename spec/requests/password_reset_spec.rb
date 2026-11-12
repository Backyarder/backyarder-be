require "spec_helper"

RSpec.describe "Password reset", type: :request do
  def body
    JSON.parse(last_response.body, symbolize_names: true)
  end

  def with_mail_configured
    %w[SMTP_HOST SMTP_USER SMTP_PASSWORD MAIL_FROM].each { |k| ENV[k] = "x" }
    ENV["MAIL_FROM"] = "garden@example.com"
    allow(DigestMailer).to receive(:configure!)
    Mail.defaults { delivery_method :test }
    Mail::TestMailer.deliveries.clear
    yield
  ensure
    %w[SMTP_HOST SMTP_USER SMTP_PASSWORD MAIL_FROM].each { |k| ENV.delete(k) }
  end

  it "is unavailable until email is configured" do
    create_user
    post "/auth/forgot", JSON.generate(email: "gardener@example.com"), json_headers
    expect(last_response.status).to eq(503)
    expect(body[:error]).to include("not set up")
  end

  it "emails a reset link and lets the user set a new password and log in" do
    with_mail_configured do
      user = create_user
      old_session = Session.issue!(user)

      post "/auth/forgot", JSON.generate(email: "GARDENER@example.com"), json_headers
      expect(last_response).to be_ok
      mail = Mail::TestMailer.deliveries.last
      expect(mail.to).to eq(["gardener@example.com"])
      token = mail.body.to_s[%r{/reset\?token=(\S+)}, 1]
      expect(token).to be_a(String)
      expect(user.reload.reset_token_digest).to eq(Session.digest(token))

      post "/auth/reset", JSON.generate(token: token, password: "short"), json_headers
      expect(last_response.status).to eq(422)
      expect(body[:error]).to include("Password is too short")

      post "/auth/reset", JSON.generate(token: token, password: "newgardening1"), json_headers
      expect(last_response).to be_ok
      expect(body[:data][:attributes][:email]).to eq("gardener@example.com")
      expect(User.authenticate("gardener@example.com", "newgardening1")).to eq(user)
      expect(User.authenticate("gardener@example.com", "gardening1")).to be_nil
      expect(Session.authenticate(old_session.token)).to be_nil, "old sessions are ended"
      expect(Session.authenticate(body[:token]).user).to eq(user), "the response signs the user in"

      post "/auth/reset", JSON.generate(token: token, password: "newgardening1"), json_headers
      expect(last_response.status).to eq(422), "the token is single use"
    end
  end

  it "answers the same for unknown addresses and sends nothing" do
    with_mail_configured do
      post "/auth/forgot", JSON.generate(email: "nobody@example.com"), json_headers
      expect(last_response).to be_ok
      expect(Mail::TestMailer.deliveries).to be_empty
    end
  end

  it "rejects expired and bogus tokens" do
    user = create_user
    token = user.issue_reset_token!(now: Time.now - User::RESET_TTL - 1)

    post "/auth/reset", JSON.generate(token: token, password: "newgardening1"), json_headers
    expect(last_response.status).to eq(422)
    post "/auth/reset", JSON.generate(token: "nope", password: "newgardening1"), json_headers
    expect(last_response.status).to eq(422)
    expect(User.authenticate("gardener@example.com", "gardening1")).to eq(user)
  end
end
