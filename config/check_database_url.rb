# Fail fast with a clear message when running in production without a usable
# DATABASE_URL. Without this, ActiveRecord silently falls back to a local Unix
# socket and the error is a confusing "connection to server on socket ... failed".
if ENV["RACK_ENV"] == "production"
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
