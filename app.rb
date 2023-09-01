require "sinatra"
require "sinatra/activerecord"

set :database_file, "config/database.yml"

require "./app/models/cell"
