# Read-through cache in front of PerenualService, and the local plant index.
#
# - Plant details and care guides are fetched once and kept forever; the
#   details-page image is downloaded at the same time so nothing about a
#   plant ever needs refreshing.
# - Thumbnails are downloaded once into the database and served by the app.
# - Search looks in our own table first (every plant we have ever listed)
#   and only asks Perenual when the local results are thin; Perenual results
#   are cached by query for SearchCache::TTL.
# - When the daily budget is gone, whatever we have locally is served; only
#   data we've never seen raises PerenualService::QuotaExceeded.
class PlantCache
  RESULTS_PER_SEARCH = 10
  LOCAL_ENOUGH = 5          # this many local matches and we skip Perenual
  CATALOG_RESERVE = 10      # calls left for users when snapshotting the catalogue
  CATALOG_PAGE_KEY = "catalog_next_page".freeze
  CATALOG_DONE_KEY = "catalog_done".freeze

  def initialize(service = PerenualService.new)
    @service = service
  end

  # Returns [details_hash, care_sections, has_image]. Up to two calls on a cold miss.
  def details(plant_id)
    record = PlantDetail.find_or_initialize_by(plant_id: plant_id)
    ensure_details(record)
    ensure_care(record)
    record.save! if record.changed?
    [record.details_hash, record.care_sections, record.image?]
  end

  # Returns [details_hash] without the care guide: at most one call on a miss.
  def details_only(plant_id)
    record = PlantDetail.find_or_initialize_by(plant_id: plant_id)
    ensure_details(record)
    record.save! if record.changed?
    [record.details_hash]
  end

  # Returns [bytes, content_type] or nil when the plant has no image.
  # At most one call on a cold miss (the care guide is not needed here).
  def thumbnail(plant_id)
    record = PlantDetail.find_or_initialize_by(plant_id: plant_id)
    return [record.thumbnail, record.thumbnail_content_type] if record.thumbnail?

    ensure_details(record)
    record.save! if record.changed?
    url = record.details_hash&.dig(:default_image, :thumbnail)
    url && store_thumbnail(plant_id, url)
  end

  # The details-page image, stored when the details were first fetched.
  def image(plant_id)
    record = PlantDetail.find_by(plant_id: plant_id)
    return nil unless record&.image?

    [record.image, record.image_content_type]
  end

  # Returns an array of listing hashes:
  #   { plant_id:, name:, cycle:, watering:, sunlight:, type:, hardiness:, has_image: }
  def search(query)
    q = query.to_s.strip.downcase
    cached = SearchCache.find_by(query: q)
    return cached.results_array if cached&.fresh?

    local = local_results(q)
    return local if local.size >= LOCAL_ENOUGH

    begin
      raw = @service.species_list(q)[:data].to_a
    rescue PerenualService::QuotaExceeded
      return cached.results_array if cached   # stale beats nothing
      return local if local.any?

      raise
    end

    remote = raw
      .reject { |r| r[:id].to_i > PerenualService::FREE_TIER_MAX_ID }
      .map { |r| remember_listing(r) }
    # Plants we already know come first; they are the ones people replant.
    results = (local + remote).uniq { |r| r[:plant_id] }.first(RESULTS_PER_SEARCH)

    (cached || SearchCache.new(query: q)).update!(results: JSON.generate(results))
    results
  end

  # --- catalogue snapshot ----------------------------------------------------

  # Walks Perenual's species list page by page, remembering every free-tier
  # plant (name, summary, thumbnail) so search can run locally. One API call
  # per page; thumbnails are plain downloads. Stops early when the budget is
  # down to CATALOG_RESERVE so users are never starved. Resumable.
  def snapshot_catalog(pages: 5)
    status = catalog_status
    return status if status[:done]

    page = status[:next_page]
    pages_done = 0
    pages.times do
      break if ApiUsage.remaining <= CATALOG_RESERVE

      body = @service.species_list_page(page)
      body[:data].to_a.each do |raw|
        next if raw[:id].to_i > PerenualService::FREE_TIER_MAX_ID

        remember_listing(raw)
      end
      pages_done += 1
      last_page = body[:last_page].to_i
      past_free_tier = body[:data].to_a.all? { |r| r[:id].to_i > PerenualService::FREE_TIER_MAX_ID } && body[:data].to_a.any?
      if body[:data].to_a.empty? || (last_page.positive? && page >= last_page) || past_free_tier
        Setting.set(CATALOG_DONE_KEY, "1")
        Setting.set(CATALOG_PAGE_KEY, page + 1)
        break
      end
      page += 1
      Setting.set(CATALOG_PAGE_KEY, page)
    end

    catalog_status.merge(pages_done: pages_done)
  end

  def catalog_status
    {
      done: Setting.get(CATALOG_DONE_KEY) == "1",
      next_page: Setting.get(CATALOG_PAGE_KEY, "1").to_i,
      plants_known: PlantDetail.listed.count,
      plants_with_details: PlantDetail.where.not(details: nil).count,
      perenual_remaining_today: ApiUsage.remaining
    }
  end

  private

  def ensure_details(record)
    return if record.details?

    data = @service.detail_search(record.plant_id)
    record.details = JSON.generate(data)
    record.details_fetched_at = Time.now
    record.common_name ||= data[:common_name]
    # Grab the page image now, while the signed link is valid (a download, not a call).
    url = data.dig(:default_image, :medium_url) || data.dig(:default_image, :regular_url)
    if url && !record.image?
      downloaded = @service.download(url)
      record.image, record.image_content_type = downloaded if downloaded
    end
  end

  def ensure_care(record)
    return unless record.care.nil?

    guide = @service.maintenance_search(record.plant_id)
    record.care = JSON.generate(guide.dig(:data, 0, :section) || [])
  end

  # Name matches from our own table: names starting with the query first.
  def local_results(q)
    return [] if q.empty?

    PlantDetail.listed.where("LOWER(common_name) LIKE ?", "%#{sanitize_like(q)}%")
      .order(:common_name)
      .limit(RESULTS_PER_SEARCH * 3)
      .map(&:listing)
      .sort_by { |r| [r[:name].to_s.downcase.start_with?(q) ? 0 : 1, r[:name].to_s.downcase] }
      .first(RESULTS_PER_SEARCH)
  end

  def sanitize_like(text)
    text.gsub(/[%_\\]/) { |c| "\\#{c}" }
  end

  # Records what a species-list entry tells us (name, summary, thumbnail)
  # and returns its listing hash.
  def remember_listing(raw)
    id = raw[:id]
    record = PlantDetail.find_or_initialize_by(plant_id: id)
    record.common_name = raw[:common_name] if raw[:common_name]
    record.summary = JSON.generate(cycle: raw[:cycle], watering: raw[:watering], sunlight: raw[:sunlight] || [],
                                   scientific_name: raw[:scientific_name])
    record.save! if record.changed?

    thumb_url = raw.dig(:default_image, :thumbnail)
    store_thumbnail(id, thumb_url) if thumb_url && !record.thumbnail?

    record.reload.listing
  end

  def store_thumbnail(plant_id, url)
    downloaded = @service.download(url)
    return nil unless downloaded

    bytes, content_type = downloaded
    record = PlantDetail.find_or_initialize_by(plant_id: plant_id)
    record.update!(thumbnail: bytes, thumbnail_content_type: content_type)
    [bytes, content_type]
  end
end
