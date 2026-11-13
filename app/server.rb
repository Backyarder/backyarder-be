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

    def image_url(plant_id)
      base = ENV["API_BASE_URL"] || "#{request.base_url}#{request.script_name}"
      "#{base}/plants/#{plant_id}/image"
    end

    def plant_cache
      @plant_cache ||= PlantCache.new
    end

    # Shared-secret check for endpoints an external scheduler calls.
    def require_cron_secret!
      secret = ENV["CRON_SECRET"].to_s
      given = params[:secret].to_s.empty? ? request.env["HTTP_X_CRON_SECRET"].to_s : params[:secret].to_s
      halt 503, json({ error: "CRON_SECRET is not set on the server." }) if secret.empty?
      halt 401, json({ error: "Bad secret." }) unless Rack::Utils.secure_compare(secret, given)
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
      plant.image = result[:image_path] || (result[:has_image] ? thumbnail_url(result[:plant_id]) : nil)
      plant.collection = result[:collection]
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
      next unless PerenualService.allowed_id?(plant.plant_id)

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

  # --- catalogue snapshot (must come before /plants/:id) --------------------

  get "/plants/catalog" do
    json plant_cache.catalog_status
  end

  # Snapshot a few pages of Perenual's catalogue into our own table so search
  # runs locally. Guarded by CRON_SECRET; call repeatedly until done: true.
  post "/plants/catalog" do
    require_cron_secret!
    pages = [[params[:pages].to_i, 1].max, 20].min
    json plant_cache.snapshot_catalog(pages: pages)
  end

  # Two Perenual calls the first time anyone views a plant, then never again.
  get "/plants/:id" do
    details, sections, image = plant_cache.details(params[:id].to_i)
    plant = Detail.new(details)
    plant.section = sections
    plant.image = image == :stored ? image_url(params[:id].to_i) : image

    cache_control :public, max_age: ONE_DAY
    json DetailSerializer.new(plant)
  end

  # The details-page image, stored with the details; never expires.
  get "/plants/:id/image" do
    result = plant_cache.image(params[:id].to_i)
    halt 404 unless result

    bytes, mime = result
    content_type mime
    cache_control :public, max_age: ONE_YEAR
    bytes
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

  # Always answers 200 so the form cannot be used to discover accounts.
  # Only sends when the address has an account and SMTP is configured.
  post "/auth/forgot" do
    halt 503, json({ error: "Password reset email is not set up on this server yet. Ask the garden owner to reset your password." }) unless DigestMailer.configured?

    user = User.find_by(email: json_body[:email].to_s.strip.downcase)
    DigestMailer.deliver_password_reset(user, user.issue_reset_token!) if user
    json({ ok: true })
  end

  # Sets a new password from an emailed token and signs the user in.
  post "/auth/reset" do
    params = json_body
    user = User.find_by_reset_token(params[:token])
    halt 422, json({ error: "That reset link is invalid or has expired. Request a new one." }) unless user

    begin
      user.reset_password!(params[:password].to_s)
    rescue ActiveRecord::RecordInvalid
      halt 422, json({ error: user.errors.full_messages.join(", ") })
    end

    session = Session.issue!(user)
    set_session_cookie(session)
    user_json(user, session)
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

  # --- alerts ---------------------------------------------------------------

  # What needs attention today: plants due for water, recent rain, frost.
  get "/alerts" do
    require_login!
    json GardenAlerts.new(current_user).to_h
  end

  # Daily email digest for every user, meant to be hit by an external cron
  # (cron-job.org) with the shared secret. ?dry_run=1 reports without sending.
  post "/alerts/digest" do
    require_cron_secret!

    result = DigestMailer.deliver_all(dry_run: params[:dry_run] == "1")
    status 502 if result[:failed].any? && result[:sent].empty?
    json result
  rescue DigestMailer::NotConfigured => e
    halt 503, json({ error: e.message })
  end

  # Does the server's mail configuration work? No mail is sent.
  ["/alerts/mail-check", "/alerts/smtp-check"].each do |path|
    get path do
      require_cron_secret!
      result = DigestMailer.check
      status 502 unless result[:ok]
      json result
    end
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
