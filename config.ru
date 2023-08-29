require "bundler"
Bundler.require

require File.expand_path("routes.rb", File.dirname(__FILE__))

run Routes
