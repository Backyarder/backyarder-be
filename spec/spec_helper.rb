ENV["RACK_ENV"] = "test"

require "vcr"
require "rspec"
require "rack/test"
require "sinatra"

require "bundler"
Bundler.require(:default, :test)

require File.expand_path("../config/environment.rb", __dir__)

require "simplecov"
SimpleCov.start

include Rack::Test::Methods
def app
  Backyarder
end

RSpec.configure do |config|
  DatabaseCleaner.strategy = :truncation

  config.before(:each) do
    DatabaseCleaner.clean
  end
  config.after(:each) do
    DatabaseCleaner.clean
  end
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  # Use :webmock as the HTTP library for handling requests
  config.hook_into :webmock
  # Enable real HTTP connections if VCR cannot find a cassette
  config.allow_http_connections_when_no_cassette = false
  config.filter_sensitive_data("<API_KEY>") { ENV["PERENUAL_API_KEY"] }
  config.debug_logger = $stdout
end
