require "mail"
require "net/smtp"

# Sends each user's GardenAlerts#message once per day.
#
# Transport: Brevo's HTTP API when BREVO_API_KEY is set (Render's free tier
# blocks outbound SMTP ports, HTTPS is fine), otherwise plain SMTP via
# SMTP_HOST, SMTP_PORT, SMTP_USER and SMTP_PASSWORD. MAIL_FROM is the sender
# either way.
class DigestMailer
  class NotConfigured < StandardError; end
  class DeliveryError < StandardError; end

  BREVO_URL = "https://api.brevo.com/v3/".freeze

  def self.brevo?
    ENV["BREVO_API_KEY"].to_s.strip != ""
  end

  def self.configured?
    return false if ENV["MAIL_FROM"].to_s.strip.empty?

    brevo? || %w[SMTP_HOST SMTP_USER SMTP_PASSWORD].all? { |k| ENV[k].to_s.strip != "" }
  end

  # Sends one plain-text message through whichever transport is configured.
  def self.deliver(to:, subject:, body:)
    if brevo?
      deliver_via_brevo(to: to, subject: subject, body: body)
    else
      configure!
      Mail.deliver do
        from ENV["MAIL_FROM"]
        to to
        subject subject
        body body
      end
    end
  end

  def self.deliver_via_brevo(to:, subject:, body:)
    response = brevo_connection.post("smtp/email") do |req|
      req.body = JSON.generate(sender: { name: "Backyarder", email: ENV["MAIL_FROM"] },
                               to: [{ email: to }], subject: subject, textContent: body)
    end
    return if response.success?

    raise DeliveryError, "Brevo answered HTTP #{response.status}: #{response.body.to_s[0, 200]}"
  rescue Faraday::Error => e
    raise DeliveryError, "Could not reach Brevo: #{e.message}"
  end

  def self.brevo_connection
    Faraday.new(BREVO_URL, headers: { "api-key" => ENV["BREVO_API_KEY"], "Content-Type" => "application/json", "Accept" => "application/json" },
                request: { open_timeout: 10, timeout: 20 })
  end

  def self.configure!
    raise NotConfigured, "Set MAIL_FROM plus BREVO_API_KEY (or SMTP_HOST, SMTP_PORT, SMTP_USER and SMTP_PASSWORD) to send email." unless configured?

    Mail.defaults do
      delivery_method :smtp, address: ENV["SMTP_HOST"], port: (ENV["SMTP_PORT"] || 587).to_i,
                             user_name: ENV["SMTP_USER"], password: ENV["SMTP_PASSWORD"],
                             authentication: :plain, enable_starttls_auto: true,
                             open_timeout: 10, read_timeout: 20
    end
  end

  # Verifies the mail transport without sending: for Brevo, reads the account
  # with the API key; for SMTP, opens a session (EHLO + login). Errors come
  # back as data, so a wrong key, host, port or password reads as a message.
  def self.check
    return { ok: false, error: "Mail is not configured (set MAIL_FROM plus BREVO_API_KEY, or SMTP_HOST, SMTP_USER and SMTP_PASSWORD)." } unless configured?
    return check_brevo if brevo?

    host = ENV["SMTP_HOST"]
    port = (ENV["SMTP_PORT"] || 587).to_i
    started = Time.now
    smtp = Net::SMTP.new(host, port)
    smtp.open_timeout = 10
    smtp.read_timeout = 20
    smtp.enable_starttls_auto
    smtp.start("localhost", ENV["SMTP_USER"], ENV["SMTP_PASSWORD"], :plain) { nil }
    { ok: true, host: host, port: port, from: ENV["MAIL_FROM"], seconds: (Time.now - started).round(2) }
  rescue StandardError => e
    { ok: false, host: host, port: port, from: ENV["MAIL_FROM"], error: "#{e.class}: #{e.message}", seconds: (Time.now - started).round(2) }
  end

  def self.check_brevo
    started = Time.now
    response = brevo_connection.get("account")
    if response.success?
      account = JSON.parse(response.body) rescue {}
      { ok: true, transport: "brevo", from: ENV["MAIL_FROM"], account_email: account["email"], seconds: (Time.now - started).round(2) }
    else
      { ok: false, transport: "brevo", from: ENV["MAIL_FROM"], error: "Brevo answered HTTP #{response.status}: #{response.body.to_s[0, 200]}", seconds: (Time.now - started).round(2) }
    end
  rescue Faraday::Error => e
    { ok: false, transport: "brevo", from: ENV["MAIL_FROM"], error: "Could not reach Brevo: #{e.message}", seconds: (Time.now - started).round(2) }
  end

  def self.subject_for(alerts)
    n = alerts.needs_water.size
    parts = []
    parts << (n == 1 ? "1 plant needs water" : "#{n} plants need water") if n.positive?
    parts << "frost is coming" if alerts.frost
    "Backyarder: #{parts.join(' and ')}"
  end

  # Emails a password reset link. Raises NotConfigured when SMTP is not set up.
  def self.deliver_password_reset(user, token)
    link = "#{ENV.fetch('APP_BASE_URL', 'https://backyarder.vercel.app')}/reset?token=#{token}"
    deliver(to: user.email, subject: "Backyarder: reset your password", body: <<~TEXT)
      Someone asked to reset the password for this Backyarder account.

      If that was you, open this link within the next hour:
      #{link}

      If it wasn't, you can ignore this email; your password has not changed.
    TEXT
  end

  # Returns { sent: [...emails], failed: [{ email:, error: }], skipped: n, dry_run: bool }.
  # A delivery failure for one user never stops the others or raises.
  def self.deliver_all(now: Time.now, dry_run: false)
    configure! unless dry_run || brevo?
    today = now.utc.to_date
    sent = []
    failed = []
    skipped = 0

    User.where.not(email: nil).find_each do |user|
      next skipped += 1 if user.last_digest_sent_on == today && !dry_run

      alerts = GardenAlerts.new(user, now: now)
      body = alerts.message
      next skipped += 1 if body.nil?

      unless dry_run
        begin
          deliver(to: user.email, subject: subject_for(alerts), body: body)
          user.update_columns(last_digest_sent_on: today)
        rescue StandardError => e
          failed << { email: user.email, error: "#{e.class}: #{e.message}" }
          next
        end
      end
      sent << user.email
    end

    { sent: sent, failed: failed, skipped: skipped, dry_run: dry_run }
  end
end
