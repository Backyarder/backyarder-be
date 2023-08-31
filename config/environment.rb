require "bundler"
Bundler.require

# get the path of the root of the app
APP_ROOT = File.expand_path("..", __dir__)

# require the controller(s)
# Dir.glob(File.join(APP_ROOT, "app", "controllers", "*.rb")).each { |file| require file }

# require the model(s)
Dir.glob(File.join(APP_ROOT, "app", "models", "*.rb")).each { |file| require file }
Dir.glob(File.join(APP_ROOT, "app", "*.rb")).each { |file| require file }

# require the serializer(s)
Dir.glob(File.join(APP_ROOT, "app", "serializers", "*.rb")).each { |file| require file }
Dir.glob(File.join(APP_ROOT, "app", "poros", "*.rb")).each { |file| require file }
Dir.glob(File.join(APP_ROOT, "app", "services", "*.rb")).each { |file| require file }

# configure TaskManagerApp settings
class Backyarder < Sinatra::Base
  set :method_override, true
  set :root, APP_ROOT
  # set :database_file, "./database.yml"
  # set :views, File.join(APP_ROOT, "app", "views")
  # set :public_folder, File.join(APP_ROOT, "app", "public")
end
