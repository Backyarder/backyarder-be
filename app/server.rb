require "json"
require "sinatra"
require "dotenv"

Dotenv.load

class Backyarder < Sinatra::Base
  ONE_HOUR = 60 * 60
  ONE_DAY = 24 * ONE_HOUR
  ONE_YEAR = 365 * ONE_DAY

  # Perenual's daily budget is gone and we have nothing cached for this request.
  error PerenualService::QuotaExceeded do
    status 503
    json({ error: "Plant data is temporarily unavailable: our daily limit for the plant database has been reached. Please try again tomorrow." })
  end

  error PerenualService::ApiError do
    status 502
    json({ error: "The plant database did not respond correctly. Please try again later." })
  end

  helpers do
    # Absolute URL for a cached thumbnail. Overridable for proxies/CDNs.
    def thumbnail_url(plant_id)
      base = ENV["API_BASE_URL"] || "#{request.base_url}#{request.script_name}"
      "#{base}/plants/#{plant_id}/thumbnail"
    end

    def plant_cache
      @plant_cache ||= PlantCache.new
    end
  end

  get "/" do
    "Welcome to Backyarder!"
  end

  # One Perenual call for a new query, zero for a repeat within a week.
  get "/search/:q" do
    results = plant_cache.search(params[:q])

    plants = results.map do |result|
      plant = Plant.new(id: result[:plant_id], common_name: result[:name])
      plant.hardiness = result[:hardiness]
      plant.image = result[:has_image] ? thumbnail_url(result[:plant_id]) : nil
      plant.type = result[:type]
      plant.sunlight = result[:sunlight]
      plant.watering = result[:watering]
      plant.content_type = "Plant"
      plant
    end

    cache_control :public, max_age: ONE_DAY
    json ListSerializer.new(plants)
  end

  # Stock plants come from snapshots in mock_json; no Perenual calls.
  get "/plants" do
    json = JSON.parse(File.read("mock_json/index.json"), symbolize_names: true)[:data]

    type = json.map do |result|
      Plant.new(result)
    end

    plants = type.map do |plant|
      next if plant.plant_id > PerenualService::FREE_TIER_MAX_ID

      plant_details = JSON.parse(File.read("mock_json/details/#{plant.plant_id}.json"), symbolize_names: true)
      plant.hardiness = plant_details[:hardiness]
      plant.image = stock_image(plant.plant_id, plant_details.dig(:default_image, :thumbnail))
      plant.type = plant_details[:type]
      plant.sunlight = plant_details[:sunlight]
      plant.watering = plant_details[:watering]
      plant.content_type = "Plant"

      plant
    end

    cache_control :public, max_age: ONE_HOUR
    json ListSerializer.new(plants)
  end

  # Two Perenual calls the first time anyone views a plant, then cached.
  get "/plants/:id" do
    details, sections = plant_cache.details(params[:id].to_i)
    plant = Detail.new(details)
    plant.section = sections

    cache_control :public, max_age: ONE_DAY
    json DetailSerializer.new(plant)
  end

  # Thumbnails are stored once and served from here with a long cache life.
  get "/plants/:id/thumbnail" do
    result = plant_cache.thumbnail(params[:id].to_i)
    halt 404 unless result

    bytes, mime = result
    content_type mime
    cache_control :public, max_age: ONE_YEAR
    bytes
  end

  get "/perenual-usage" do
    json ApiUsage.summary
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

  # Uses the image stored on each cell when it was placed; no Perenual calls.
  get "/garden-stats" do
    response = {}
    Cell.where.not(plant_id: nil).each do |cell|
      if response[cell.name]
        response[cell.name][:count] += 1
      else
        response[cell.name] = { image: cell.image, count: 1 }
      end
    end

    json response
  end

  get "/decor" do
    json = JSON.parse(File.read("mock_json/decor_item_index.json"), symbolize_names: true)[:data]

    items = json.map do |decor|
      DecorItem.new(decor)
    end

    json DecorItemSerializer.new(items)
  end

  private

  # Snapshots that point at a frontend-hosted file keep that (free and fast);
  # anything else is served from the cached thumbnail route.
  def stock_image(plant_id, snapshot_thumbnail)
    return nil if snapshot_thumbnail.nil?
    return snapshot_thumbnail if snapshot_thumbnail.start_with?("/images/")

    thumbnail_url(plant_id)
  end
end
