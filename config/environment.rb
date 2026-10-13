require "bundler"
Bundler.require

# require "./app/server.rb"

# get the path of the root of the app
APP_ROOT = File.expand_path("..", __dir__)

# require the controller(s)
# Dir.glob(File.join(APP_ROOT, "app", "controllers", "*.rb")).each { |file| require file }

# Load order matters: the server's error handlers reference service classes
# at class-definition time, so everything else loads before app/server.rb.
Dir.glob(File.join(APP_ROOT, "app", "models", "*.rb")).each { |file| require file }
Dir.glob(File.join(APP_ROOT, "app", "serializers", "*.rb")).each { |file| require file }
Dir.glob(File.join(APP_ROOT, "app", "poros", "*.rb")).each { |file| require file }
Dir.glob(File.join(APP_ROOT, "app", "services", "*.rb")).each { |file| require file }
Dir.glob(File.join(APP_ROOT, "app", "*.rb")).each { |file| require file }

# configure TaskManagerApp settings
class Backyarder < Sinatra::Base
  set :method_override, true
  set :root, APP_ROOT
  # Let custom `error` handlers (e.g. Perenual quota -> 503) run in development
  # too; only unhandled exceptions get Sinatra's debug page.
  set :show_exceptions, :after_handler
  # set :database_file, "./database.yml"
  # set :views, File.join(APP_ROOT, "app", "views")
  # set :public_folder, File.join(APP_ROOT, "app", "public")
end
