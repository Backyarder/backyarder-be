require "spec_helper"

RSpec.describe DigestMailer do
  let(:now) { Time.utc(2026, 11, 12, 14, 0, 0) }
  let(:day) { 24 * 60 * 60 }

  before do
    ENV["MAIL_FROM"] = "garden@example.com"
    Mail.defaults { delivery_method :test }
    Mail::TestMailer.deliveries.clear
    stub_request(:get, %r{api\.open-meteo\.com}).to_return(status: 500, body: "")
  end

  after { ENV.delete("MAIL_FROM") }

  def user_with_due_plant(email)
    user = User.create!(email: email, password: "gardening1")
    user.garden.cells.find_by(location_id: "A1").update!(status: :locked, name: "Fern", plant_id: 1, content_type: "Plant", watering: :Frequent, planted_at: now - 9 * day, last_watered_at: now - 9 * day)
    user
  end

  it "emails each user with something due, once per day" do
    due = user_with_due_plant("due@example.com")
    User.create!(email: "quiet@example.com", password: "gardening1").garden

    allow(described_class).to receive(:configure!)
    result = described_class.deliver_all(now: now)

    expect(result).to include(sent: ["due@example.com"], failed: [], skipped: 1)
    mail = Mail::TestMailer.deliveries.last
    expect(mail.to).to eq(["due@example.com"])
    expect(mail.subject).to eq("Backyarder: 1 plant needs water")
    expect(mail.from).to eq(["garden@example.com"])
    expect(mail.body.to_s).to include("Fern in A1")
    expect(due.reload.last_digest_sent_on).to eq(now.to_date)

    expect(described_class.deliver_all(now: now + 60)).to include(sent: [], skipped: 2)
    expect(Mail::TestMailer.deliveries.size).to eq(1)
  end

  it "dry runs without configuration or sending" do
    user_with_due_plant("due@example.com")

    result = described_class.deliver_all(now: now, dry_run: true)

    expect(result).to eq(sent: ["due@example.com"], failed: [], skipped: 0, dry_run: true)
    expect(Mail::TestMailer.deliveries).to be_empty
  end

  it "reports a delivery failure for one user and carries on with the others" do
    user_with_due_plant("first@example.com")
    user_with_due_plant("second@example.com")
    allow(described_class).to receive(:configure!)
    calls = 0
    allow(Mail).to receive(:deliver) do
      calls += 1
      raise Net::OpenTimeout, "execution expired" if calls == 1
    end

    result = described_class.deliver_all(now: now)

    expect(result[:failed]).to eq([{ email: "first@example.com", error: "Net::OpenTimeout: execution expired" }])
    expect(result[:sent]).to eq(["second@example.com"])
    expect(User.find_by(email: "first@example.com").last_digest_sent_on).to be_nil
    expect(User.find_by(email: "second@example.com").last_digest_sent_on).to eq(now.to_date)
  end

  it "checks the SMTP connection and reports errors as data" do
    expect(described_class.check).to include(ok: false)
    expect(described_class.check[:error]).to include("not configured")

    %w[SMTP_HOST SMTP_USER SMTP_PASSWORD].each { |k| ENV[k] = "x" }
    ENV["SMTP_HOST"] = "smtp.example.test"
    smtp = instance_double(Net::SMTP, "open_timeout=": nil, "read_timeout=": nil, enable_starttls_auto: nil)
    allow(Net::SMTP).to receive(:new).with("smtp.example.test", 587).and_return(smtp)

    allow(smtp).to receive(:start).and_raise(Net::OpenTimeout, "execution expired")
    expect(described_class.check).to include(ok: false, host: "smtp.example.test", port: 587, error: "Net::OpenTimeout: execution expired")

    allow(smtp).to receive(:start).and_return(nil)
    expect(described_class.check).to include(ok: true, host: "smtp.example.test", port: 587)
  ensure
    %w[SMTP_HOST SMTP_USER SMTP_PASSWORD].each { |k| ENV.delete(k) }
  end

  it "refuses to send when SMTP is not configured" do
    expect { described_class.deliver_all(now: now) }.to raise_error(DigestMailer::NotConfigured)
  end
end
