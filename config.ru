require File.expand_path("config/check_database_url", __dir__)

require "bundler"
Bundler.require

require File.expand_path("config/environment", __dir__)
# require File.expand_path("routes.rb", File.dirname(__FILE__))
require "rack/cors"

use Rack::Cors do
  allow do
    if %w[development test staging].include?(ENV["RACK_ENV"])
      # Allow the local frontend dev server on any localhost port (http or https),
      # with cookies, for setups that do not go through the CRA proxy.
      origins %r{\Ahttps?://localhost(:\d+)?\z}
      resource "*", :headers => :any, :methods => [:get, :patch, :post, :delete, :options], :credentials => true
    else
      # Production is same-origin (Vercel rewrites /api/v1 to this service), so
      # browsers never need CORS; this keeps curl and scripts working.
      origins "*"
      resource "*", :headers => :any, :methods => [:get, :patch, :post, :delete, :options]
    end
  end
end

map("/api/v1") { run Backyarder }
