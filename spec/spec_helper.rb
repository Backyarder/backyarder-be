ENV["RACK_ENV"] = "test"

require "rspec"

require "bundler"
Bundler.require(:default, :test)

require File.expand_path("../../config/environment.rb", __FILE__)

require "simplecov"
SimpleCov.start

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
