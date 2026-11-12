ENV["RACK_ENV"] = "test"

require "vcr"
require "rspec"
require "rack/test"
require "sinatra"
require 'webmock/rspec'

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
    # Default image bytes for any thumbnail or page image download.
    stub_request(:get, %r{perenual\.com/storage/|wasabisys\.com/}).to_return(status: 200, body: "imagebytes", headers: { "Content-Type" => "image/jpeg" })
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
  config.filter_sensitive_data("<API_KEY>") { ENV["UNSPLASH_ACCESS_KEY"] }
  # Image downloads from Perenual's bucket are not API calls and are not in
  # the cassettes; let the WebMock stub below answer them inside cassettes too.
  config.ignore_request { |request| !request.uri.include?("perenual.com/api/") }
  config.debug_logger = $stdout
end

WebMock.disable_net_connect!(allow_localhost: true)

# --- request spec helpers ----------------------------------------------------

# Signs in as `user` for request specs by issuing a session and returning the
# rack env headers that carry it (merge into the env argument of get/patch/...).
def auth_headers(user)
  session = Session.issue!(user)
  { "HTTP_AUTHORIZATION" => "Bearer #{session.token}" }
end

def json_headers(user = nil)
  headers = { "CONTENT_TYPE" => "application/json" }
  user ? headers.merge(auth_headers(user)) : headers
end

def create_user(email = "gardener@example.com", password: "gardening1")
  User.create!(email: email, password: password)
end

def stub_hardiness(zip, zone: "8a", lat: "34.306643", lon: "-83.82352")
  stub_request(:get, "https://phzmapi.org/#{zip}.json")
    .to_return(status: 200, body: JSON.generate(zone: zone, temperature_range: "10 to 15", coordinates: { lat: lat, lon: lon }))
end

def stub_unknown_zip(zip)
  stub_request(:get, "https://phzmapi.org/#{zip}.json").to_return(status: 404, body: "")
end
