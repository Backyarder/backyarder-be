require "json"
require "sinatra"
require "dotenv"
Dotenv.load

class Server < Sinatra::Base
  get "/" do
    "Welcome to Backyarder!"
  end

  get "/search/:q" do
    query = params[:q]
    api = PerenualService.new.search(query)[:data]
    search = api.map do |a|
      Search.new(a)
    end

    type = search[0..4].map do |s|
      if s.plant_id <= 3000
        show = PerenualService.new.detail_search(s.plant_id)
        s.hardiness = show[:hardiness]
        s.image = show.dig(:default_image, :thumbnail)
        s.type = show[:type]
        s.sunlight = show[:sunlight]

        s
      end
    end

    json SearchSerializer.new(type)
  end
end
