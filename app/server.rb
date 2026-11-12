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

  SESSION_COOKIE = "backyarder_session".freeze

  helpers do
    # --- authentication ---------------------------------------------------

    # The session token travels as an httpOnly cookie (browser) or a bearer
    # token (scripts, specs).
    def session_token
      auth = request.env["HTTP_AUTHORIZATION"].to_s
      return auth.sub(/\ABearer\s+/i, "") if auth.match?(/\ABearer\s+\S/i)

      request.cookies[SESSION_COOKIE]
    end

    def current_session
      return @current_session if defined?(@current_session)

      @current_session = Session.authenticate(session_token)
    end

    def current_user
      current_session&.user
    end

    def current_garden
      @current_garden ||= current_user.garden
    end

    def require_login!
      return if current_user

      halt 401, json({ error: "Please log in." })
    end

    def set_session_cookie(session)
      response.set_cookie(SESSION_COOKIE,
                          value: session.token,
                          path: "/",
                          httponly: true,
                          secure: ENV["RACK_ENV"] == "production",
                          same_site: :lax,
                          expires: session.expires_at)
    end

    def clear_session_cookie
      response.delete_cookie(SESSION_COOKIE, path: "/")
    end

    def json_body
      body = request.body.read
      request.body.rewind
      body.to_s.empty? ? {} : JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError
      halt 400, json({ error: "Request body must be JSON." })
    end

    def user_json(user, session = nil)
      payload = UserSerializer.new(user).serializable_hash
      payload[:token] = session.token if session
      json payload
    end

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

  # --- accounts -------------------------------------------------------------

  post "/auth/signup" do
    params = json_body
    user = User.new(email: params[:email], password: params[:password])
    apply_zip_code!(user, params[:zip_code]) if params.key?(:zip_code)

    # A failed zip lookup adds an error that save's validation pass would clear.
    halt 422, json({ error: user.errors.full_messages.join(", ") }) unless user.errors.empty? && user.save

    Garden.claim_shared!(user)
    session = Session.issue!(user)
    set_session_cookie(session)
    status 201
    user_json(user, session)
  end

  post "/auth/login" do
    params = json_body
    user = User.authenticate(params[:email], params[:password])
    halt 401, json({ error: "Email or password is incorrect." }) unless user

    session = Session.issue!(user)
    set_session_cookie(session)
    user_json(user, session)
  end

  delete "/auth/logout" do
    current_session&.destroy
    clear_session_cookie
    status 204
  end

  get "/auth/me" do
    require_login!
    user_json(current_user)
  end

  # Update settings. zip_code is looked up for a hardiness zone; an unknown
  # zip is rejected rather than stored.
  patch "/auth/me" do
    require_login!
    params = json_body
    apply_zip_code!(current_user, params[:zip_code]) if params.key?(:zip_code)
    halt 422, json({ error: current_user.errors.full_messages.join(", ") }) unless current_user.errors.empty? && current_user.save

    user_json(current_user)
  end

  # --- wishlist -------------------------------------------------------------

  get "/wishlist" do
    require_login!
    json WishlistItemSerializer.new(current_user.wishlist_items.order(:id))
  end

  post "/wishlist" do
    require_login!
    item = current_user.wishlist_items.find_or_create_by!(plant_id: Integer(json_body[:plant_id]))
    status 201
    json WishlistItemSerializer.new(item)
  rescue ArgumentError, TypeError, ActiveRecord::RecordInvalid
    halt 422, json({ error: "plant_id must be a number." })
  end

  delete "/wishlist/:plant_id" do
    require_login!
    current_user.wishlist_items.where(plant_id: params[:plant_id].to_i).destroy_all
    status 204
  end

  # --- garden (always the signed-in user's) ---------------------------------

  get "/garden" do
    require_login!
    json CellSerializer.new(current_garden.cells.order(:id))
  end

  patch "/cell" do
    require_login!
    params = json_body
    cell = current_garden.cells.find_by(location_id: params[:location_id])
    halt 404, json({ error: "No cell #{params[:location_id].inspect} in your garden." }) unless cell

    case params[:action]
    when "remove_plant"
      cell.clear!
    when "disable_cell"
      cell.update(status: :disabled)
    when "water"
      cell.water!
    else
      watering = params[:watering]
      # Search results from the lightweight species-list call may not carry a
      # watering value; look it up (cached, or one call) so alerts keep working.
      watering = backfill_watering(params[:plant_id]) if watering.nil? && params[:content_type] == "Plant" && params[:plant_id]

      attrs = { status: params[:status], plant_id: params[:plant_id], image: params[:image], name: params[:name], watering: watering, content_type: params[:content_type] }
      attrs.merge!(care_timestamps_for(cell, params[:status]))
      cell.update(attrs)
    end

    json CellSerializer.new(cell)
  end

  delete "/garden" do
    require_login!
    current_garden.cells.where(status: :placed).update_all(Cell::CLEARED)

    status 200
  end

  delete "/all" do
    require_login!
    current_garden.cells.update_all(Cell::CLEARED)

    status 200
  end

  # Uses the image stored on each cell when it was placed; no Perenual calls.
  get "/garden-stats" do
    require_login!
    response = {}
    current_garden.cells.where.not(plant_id: nil).each do |cell|
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

  # Sets zip_code plus the derived hardiness zone and coordinates, or adds a
  # validation error if the zip is unknown. A blank zip clears all of them.
  def apply_zip_code!(user, zip_code)
    zip = zip_code.to_s.strip
    if zip.empty?
      user.assign_attributes(zip_code: nil, hardiness_zone: nil, latitude: nil, longitude: nil)
      return
    end

    info = HardinessService.new.lookup(zip)
    if info
      user.assign_attributes(zip_code: zip, hardiness_zone: info[:zone], latitude: info[:latitude], longitude: info[:longitude])
    else
      user.zip_code = zip
      user.errors.add(:zip_code, "could not be found; is it a valid US zip code?")
    end
  end

  # The frontend locks a cell when a plant goes in the ground and re-locks it
  # (placed -> locked) to water it, so every transition to locked is a watering.
  # Emptying a cell forgets its history. Other status changes leave it alone.
  def care_timestamps_for(cell, raw_status, now = Time.now)
    status_name = raw_status.is_a?(Integer) ? Cell.statuses.key(raw_status) : raw_status.to_s
    case status_name
    when "locked" then { planted_at: cell.planted_at || now, last_watered_at: now }
    when "empty" then { planted_at: nil, last_watered_at: nil }
    else {}
    end
  end

  # Returns the Cell#watering enum key ("Minimum", "Average", "Frequent") for a
  # plant, or nil if Perenual doesn't know or the budget is gone.
  def backfill_watering(plant_id)
    details, = plant_cache.details_only(plant_id.to_i)
    value = details && details[:watering]
    Cell.waterings.key?(value) ? value : nil
  rescue PerenualService::Error
    nil
  end

  # Snapshots that point at a frontend-hosted file keep that (free and fast);
  # anything else is served from the cached thumbnail route.
  def stock_image(plant_id, snapshot_thumbnail)
    return nil if snapshot_thumbnail.nil?
    return snapshot_thumbnail if snapshot_thumbnail.start_with?("/images/")

    thumbnail_url(plant_id)
  end
end
