# Read-through cache in front of PerenualService.
#
# - Plant details and care guides are cached forever (the data is static).
#   Only the signed image URLs inside the details expire, so a record older
#   than PlantDetail::IMAGE_TTL is refreshed with a single call when viewed.
# - Thumbnails are downloaded once into the database and served by the app.
# - Search results are cached by normalized query for SearchCache::TTL.
# - When the daily budget is gone, stale cached data is served rather than
#   failing; only data we've never seen raises PerenualService::QuotaExceeded.
class PlantCache
  RESULTS_PER_SEARCH = 10

  def initialize(service = PerenualService.new)
    @service = service
  end

  # Returns [details_hash, care_sections]. Up to two calls on a cold miss.
  def details(plant_id)
    record = PlantDetail.find_or_initialize_by(plant_id: plant_id)
    ensure_details(record)
    ensure_care(record)
    record.save! if record.changed?
    [record.details_hash, record.care_sections]
  end

  # Returns [bytes, content_type] or nil when the plant has no image.
  # At most one call on a cold miss (the care guide is not needed here).
  def thumbnail(plant_id)
    record = PlantDetail.find_or_initialize_by(plant_id: plant_id)
    return [record.thumbnail, record.thumbnail_content_type] if record.thumbnail?

    ensure_details(record)
    record.save! if record.changed?
    url = record.details_hash.dig(:default_image, :thumbnail)
    url && store_thumbnail(plant_id, url)
  end

  # Returns an array of result hashes:
  #   { plant_id:, name:, cycle:, watering:, sunlight:, type:, hardiness:, has_image: }
  def search(query)
    q = query.to_s.strip.downcase
    cached = SearchCache.find_by(query: q)
    return cached.results_array if cached&.fresh?

    begin
      raw = @service.species_list(q)[:data].to_a
    rescue PerenualService::QuotaExceeded
      raise unless cached # serve stale results rather than nothing

      return cached.results_array
    end

    results = raw
      .reject { |r| r[:id].to_i > PerenualService::FREE_TIER_MAX_ID }
      .first(RESULTS_PER_SEARCH)
      .map { |r| build_result(r) }

    (cached || SearchCache.new(query: q)).update!(results: JSON.generate(results))
    results
  end

  private

  def ensure_details(record)
    return if record.details_fresh?

    data = @service.detail_search(record.plant_id)
    record.details = JSON.generate(data)
    record.details_fetched_at = Time.now
  rescue PerenualService::QuotaExceeded
    raise if record.details.blank? # nothing stale to fall back on
  end

  def ensure_care(record)
    return unless record.care.nil?

    guide = @service.maintenance_search(record.plant_id)
    record.care = JSON.generate(guide.dig(:data, 0, :section) || [])
  end

  def build_result(raw)
    id = raw[:id]
    record = PlantDetail.find_by(plant_id: id)
    known = record&.details_hash || {}

    # Grab the thumbnail now while we have a signed URL. This is a bucket
    # download, not an API call, so it costs nothing against the budget.
    thumb_url = raw.dig(:default_image, :thumbnail)
    stored = if record&.thumbnail?
               true
             else
               (thumb_url && store_thumbnail(id, thumb_url)).present?
             end

    {
      plant_id: id,
      name: raw[:common_name],
      cycle: raw[:cycle],
      watering: raw[:watering],
      sunlight: raw[:sunlight] || [],
      type: known[:type],
      hardiness: known[:hardiness],
      has_image: stored
    }
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
