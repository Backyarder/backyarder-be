require "bundler"
Bundler.require

require File.expand_path("config/environment", __dir__)
# require File.expand_path("routes.rb", File.dirname(__FILE__))
require "rack/cors"
require "./app/v1/server"

use Rack::Cors do
  allow do
    if ENV["RACK_ENV"] == "development"
      origins "https://localhost:3000"
    elsif ENV["RACK_ENV"] == "test"
      origins "https://localhost:3000"
    elsif ENV["RACK_ENV"] == "staging"
      origins "https://localhost:3000"
    else
      origins "*"
    end

    resource "*", :headers => :any, :methods => [:get, :post, :options]
  end
end

map("/api/v1") { run Backyarder }
