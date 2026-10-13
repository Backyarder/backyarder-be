# Fail fast with a clear message when the environment is misconfigured, before
# sinatra-activerecord tries to connect and produces a confusing stack trace.

# RACK_ENV must match an entry in config/database.yml. An unknown value (for
# example a typo like "deployment") makes sinatra-activerecord hand the whole
# file to ActiveRecord, which fails with "database configuration does not
# specify adapter". Unset is fine: Sinatra defaults to development.
KNOWN_ENVIRONMENTS = %w[development test production].freeze
rack_env = ENV["RACK_ENV"].to_s.strip
if !rack_env.empty? && !KNOWN_ENVIRONMENTS.include?(rack_env)
  abort <<~MSG
    RACK_ENV is set to #{rack_env.inspect}, which is not a known environment.
    Expected one of: #{KNOWN_ENVIRONMENTS.join(", ")}.
    On Render this should be RACK_ENV=production.
  MSG
end

# In production, require a usable DATABASE_URL. Without this, ActiveRecord
# silently falls back to a local Unix socket and the error is a confusing
# "connection to server on socket ... failed".
if rack_env == "production"
  url = ENV["DATABASE_URL"].to_s.strip
  unless url.match?(%r{\Apostgres(ql)?://})
    shown = url.empty? ? "(not set)" : url.sub(/:[^:@\/]+@/, ":***@")
    abort <<~MSG
      DATABASE_URL must be set to a postgresql:// connection string in production.
      Current value: #{shown}
      Set it as an environment variable (not a secret file), with no surrounding quotes.
    MSG
  end
end
