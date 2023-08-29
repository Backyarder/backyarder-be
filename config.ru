require 'bundler'
Bundler.require

require File.expand_path('../config/environment',  __FILE__)
# require File.expand_path("routes.rb", File.dirname(__FILE__))

run Routes
