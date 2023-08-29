require "sinatra"

class Routes < Sinatra::Base
  get "/" do
    "Hello World!"
  end
end
