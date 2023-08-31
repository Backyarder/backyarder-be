require "json"
require "sinatra"
require "dotenv"
Dotenv.load

class Server < Sinatra::Base
  get "/" do
    "Hello World!"
  end

  get "/search" do
    query = params[:q]
    api = PerenualService.new.search(query)[:data]
    search = api.map do |a|
      Search.new(a)
    end

    type = search.map do |s|
      show = PerenualService.new.detail_search(s.id)
      s.hardiness = show[:hardiness]
      s.image = show.dig(:default_image, :thumbnail)
      s.type = show[:type]
      s.sunlight = show[:sunlight]

      s
    end

    json SearchSerializer.new(type)
  end
end
