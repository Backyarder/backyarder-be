require "bundler"
Bundler.require

require File.expand_path("config/environment", __dir__)
# require File.expand_path("routes.rb", File.dirname(__FILE__))
require "rack/cors"

use Rack::Cors do
  allow do
    if %w[development test staging].include?(ENV["RACK_ENV"])
      # Allow the local frontend dev server on any localhost port (http or https)
      origins %r{\Ahttps?://localhost(:\d+)?\z}
    else
      origins "*"
    end

    resource "*", :headers => :any, :methods => [:get, :patch, :post, :delete, :options]
  end
end

map("/api/v1") { run Backyarder }
