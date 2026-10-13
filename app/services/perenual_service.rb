# Thin client for the Perenual API. Every call goes through #get, which
# enforces the daily budget (ApiUsage) and turns HTTP failures into typed
# errors the app can map to friendly responses. Callers should go through
# PlantCache rather than hitting this directly.
class PerenualService
  class Error < StandardError; end
  class QuotaExceeded < Error; end
  class ApiError < Error; end

  BASE_URL = "https://perenual.com/api/".freeze
  FREE_TIER_MAX_ID = 3000

  def conn
    Faraday.new(BASE_URL)
  end

  # One call. Returns name, image, cycle, watering and sunlight for each match.
  def species_list(query)
    get("v2/species-list", q: query)
  end

  def detail_search(plant_id)
    # The v1 species/details endpoint is deprecated and returns null for most
    # fields (type, cycle, watering, hardiness, ...). v2 returns the full record.
    get("v2/species/details/#{plant_id}")
  end

  def maintenance_search(plant_id)
    get("species-care-guide-list", species_id: plant_id, page: 1)
  end

  # Fetches a binary asset (e.g. a thumbnail from Perenual's image bucket).
  # Not an API call, so it does not count toward the daily budget.
  def download(url)
    response = Faraday.new.get(url)
    return nil unless response.success? && response.headers["content-type"].to_s.start_with?("image/")

    [response.body, response.headers["content-type"]]
  rescue Faraday::Error
    nil
  end

  private

  def get(path, params = {})
    if ApiUsage.remaining <= 0
      raise QuotaExceeded, "Perenual daily request budget (#{ApiUsage.limit}) is used up"
    end

    ApiUsage.record!
    response = conn.get(path, params.merge(key: ENV["PERENUAL_API_KEY"]))
    record_rate_limit(response)

    raise QuotaExceeded, "Perenual returned 429 Too Many Requests" if response.status == 429
    raise ApiError, "Perenual returned HTTP #{response.status}" unless response.success?

    JSON.parse(response.body, symbolize_names: true)
  rescue JSON::ParserError
    raise ApiError, "Perenual returned an unreadable response"
  rescue Faraday::Error => e
    raise ApiError, "Could not reach Perenual: #{e.message}"
  end

  # Perenual sends X-RateLimit-Remaining / X-RateLimit-Reset as headers on
  # normal responses and as a JSON body on 429s. Keep whichever we got.
  def record_rate_limit(response)
    headers = response.headers
    remaining = headers["x-ratelimit-remaining"]
    reset = headers["x-ratelimit-reset"]

    if response.status == 429 && (remaining.nil? || reset.nil?)
      body = JSON.parse(response.body) rescue {}
      remaining ||= body["X-RateLimit-Remaining"]
      reset ||= body["X-RateLimit-Reset"]
    end
    return if remaining.nil?

    reset_at = reset ? Time.at(reset.to_i).utc : Time.now.utc + 24 * 60 * 60
    ApiUsage.report!(remaining: remaining, reset_at: reset_at)
  rescue StandardError
    nil # never let bookkeeping break a request
  end
end
