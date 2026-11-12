require "mail"

# Sends each user's GardenAlerts#message once per day over SMTP. Configure
# with SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD and MAIL_FROM; any
# free SMTP relay (Gmail app password, Brevo, ...) works.
class DigestMailer
  class NotConfigured < StandardError; end

  def self.configured?
    %w[SMTP_HOST SMTP_USER SMTP_PASSWORD MAIL_FROM].all? { |k| ENV[k].to_s.strip != "" }
  end

  def self.configure!
    raise NotConfigured, "Set SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD and MAIL_FROM to send email." unless configured?

    Mail.defaults do
      delivery_method :smtp, address: ENV["SMTP_HOST"], port: (ENV["SMTP_PORT"] || 587).to_i,
                             user_name: ENV["SMTP_USER"], password: ENV["SMTP_PASSWORD"],
                             authentication: :plain, enable_starttls_auto: true
    end
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
    configure!
    link = "#{ENV.fetch('APP_BASE_URL', 'https://backyarder.vercel.app')}/reset?token=#{token}"
    Mail.deliver do
      from ENV["MAIL_FROM"]
      to user.email
      subject "Backyarder: reset your password"
      body <<~TEXT
        Someone asked to reset the password for this Backyarder account.

        If that was you, open this link within the next hour:
        #{link}

        If it wasn't, you can ignore this email; your password has not changed.
      TEXT
    end
  end

  # Returns { sent: [...emails], skipped: n, dry_run: bool }.
  def self.deliver_all(now: Time.now, dry_run: false)
    configure! unless dry_run
    today = now.utc.to_date
    sent = []
    skipped = 0

    User.where.not(email: nil).find_each do |user|
      next skipped += 1 if user.last_digest_sent_on == today && !dry_run

      alerts = GardenAlerts.new(user, now: now)
      body = alerts.message
      next skipped += 1 if body.nil?

      unless dry_run
        Mail.deliver do
          from ENV["MAIL_FROM"]
          to user.email
          subject DigestMailer.subject_for(alerts)
          body body
        end
        user.update_columns(last_digest_sent_on: today)
      end
      sent << user.email
    end

    { sent: sent, skipped: skipped, dry_run: dry_run }
  end
end
