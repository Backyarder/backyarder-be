# connect ActiveRecord with the current database
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => "db/backyarder-development"
)
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => "db/backyarder-test"
)
ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :database => "backyarder"
)
