require "bundler"
Bundler.require

require File.expand_path("config/environment", __dir__)
# require File.expand_path("routes.rb", File.dirname(__FILE__))
require "rack/cors"

use Rack::Cors do
  allow do
    if ENV['RACK_ENV'] == 'production'
      origins 'https://your-production-frontend.com'
    elsif ENV['RACK_ENV'] == 'staging'
      origins 'https://your-staging-frontend.com'
    else
      origins '*'  # for development and test
    end

    resource '*', :headers => :any, :methods => [:get, :post, :options]
  end
end

run Backyarder
