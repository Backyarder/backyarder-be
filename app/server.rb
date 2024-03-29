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
      plant.watering = show[:watering]
      plant.content_type = "Plant"

      plant
    end

    json ListSerializer.new(type)
  end

  get "/plants" do
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
      plant.watering = plant_details[:watering]
      plant.content_type = "Plant"

      plant
    end

    json ListSerializer.new(plants)
  end

  get "/plants/:id" do
    show = PerenualService.new.detail_search(params[:id])
    plant = Detail.new(show)

    maintenance = PerenualService.new.maintenance_search(params[:id])[:data][0]
    plant.section = maintenance[:section]

    json DetailSerializer.new(plant)
  end

  get "/garden" do
    json CellSerializer.new(Cell.all)
  end

  patch "/cell" do
    params = JSON.parse(request.body.string, symbolize_names: true)
    cell = Cell.find_by(location_id: params[:location_id])

    case params[:action]
    when "remove_plant"
      cell.update(status: :empty, plant_id: nil, image: nil, name: nil, content_type: nil, watering: nil)
    when "disable_cell"
      cell.update(status: :disabled)
    else
      cell.update(status: params[:status], plant_id: params[:plant_id], image: params[:image], name: params[:name], watering: params[:watering], content_type: params[:content_type])
    end

    json CellSerializer.new(cell)
  end

  delete "/garden" do
    Cell.where(status: :placed).update_all(status: :empty, plant_id: nil, image: nil, name: nil, content_type: nil)

    status 200
  end

  delete "/all" do
    Cell.update_all(status: :empty, plant_id: nil, image: nil, name: nil, content_type: nil)

    status 200
  end

  get "/garden-stats" do
    cells = Cell.all
    response = {}
    cells.each do |cell|
      if response[cell.name]
        response[cell.name][:count] += 1
      else
        api_call = PerenualService.new.detail_search(cell.plant_id)
        response[cell.name] = { image: api_call[:default_image][:small_url], count: 1 }
      end
    end

    json response
  end


  get '/decor' do
    json = JSON.parse(File.read("mock_json/decor_item_index.json"), symbolize_names: true)[:data]

    items = json.map do |decor|
      DecorItem.new(decor)
    end

    json DecorItemSerializer.new(items)
  end
end
