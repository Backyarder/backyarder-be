source "https://rubygems.org"

ruby "~> 3.2.2"

gem "activerecord"
gem "bcrypt"
gem "dotenv"
gem "faraday"
gem "json"
gem "jsonapi-serializer"
gem "pry"
gem "puma"
gem "rack", "~> 2.2"
gem "rack-cors", require: "rack/cors"
gem "rack-test"
gem "rake"
gem "sinatra", require: "sinatra/base"
gem "sinatra-activerecord"
gem "sinatra-contrib"
gem "sqlite3"
gem "tux"

group :development do
  gem "rerun" # file-watching dev server; its ffi dependency does not build on current macOS
end

group :development, :test do
  gem "database_cleaner-active_record"
  gem "rspec"
end

group :test do
  gem "simplecov"
  gem "vcr"
  gem "webmock"
end

group :production do
  gem "pg"
end
