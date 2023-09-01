require "json"
require "sinatra"
require "dotenv"
Dotenv.load

class Backyarder < Sinatra::Base
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

    json ListSerializer.new(type)
  end

  get "/index" do
    json = JSON.parse(File.read("mock_json/index.json"), symbolize_names: true)[:data]

    type = json.map do |result|
      Plant.new(result)
    end

    plants = type.map do |plant|
      next if plant.plant_id > 3000

      plant_details = JSON.parse(File.read("mock_json/details/#{plant.plant_id}.json"), symbolize_names: true)
      plant.hardiness = plant_details[:hardiness]
      plant.image = plant_details.dig(:default_image, :thumbnail)
      plant.type = plant_details[:type]
      plant.sunlight = plant_details[:sunlight]

      plant
    end

    json ListSerializer.new(plants)
  end
end
