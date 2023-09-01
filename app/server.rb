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
    search = api.map do |result|
      Search.new(result)
    end

    type = search[0..9].map do |plant|
      next if plant.plant_id > 3000

      show = PerenualService.new.detail_search(plant.plant_id)
      plant.hardiness = show[:hardiness]
      plant.image = show.dig(:default_image, :thumbnail)
      plant.type = show[:type]
      plant.sunlight = show[:sunlight]

      plant
    end

    json SearchSerializer.new(type)
  end

  get "/index" do
    json = JSON.parse(File.read("mock_json/index.json"), symbolize_names: true)[:data]

    type = json.map do |result|
      Plant.new(result)
    end

    plants = type.map do |plant|
      next if plant.plant_id > 3000

      plant_details = JSON.parse(File.read("mock_json/details/#{plant[:id]}.json"), symbolize_names: true)[:data]
      plant.hardiness = show[:hardiness]
      plant.image = show.dig(:default_image, :thumbnail)
      plant.type = show[:type]
      plant.sunlight = show[:sunlight]

      plant
    end

    json SearchSerializer.new(plants)
  end

end
