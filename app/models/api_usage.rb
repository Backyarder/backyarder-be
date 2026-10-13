# Counts Perenual API calls per UTC day so we can stop short of the free-tier
# limit instead of discovering it as a 429.
class ApiUsage < ActiveRecord::Base
  DEFAULT_LIMIT = 95 # free tier allows 100/day; keep a small margin

  def self.limit
    (ENV["PERENUAL_DAILY_LIMIT"] || DEFAULT_LIMIT).to_i
  end

  def self.today
    Time.now.utc.to_date
  end

  def self.count_today
    find_by(day: today)&.count || 0
  end

  # Our own tally, capped by whatever Perenual last told us (if anything).
  def self.remaining
    own = [limit - count_today, 0].max
    row = find_by(day: today)
    return own unless row&.reported_remaining && row.reported_reset_at && row.reported_reset_at > Time.now.utc

    [own, row.reported_remaining].min
  end

  # Store what Perenual reported in its X-RateLimit-* headers / 429 body.
  def self.report!(remaining:, reset_at:)
    row = find_or_create_by!(day: today)
    row.update_columns(reported_remaining: remaining.to_i, reported_reset_at: reset_at)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # Increments today's counter and returns the new count.
  def self.record!
    row = find_or_create_by!(day: today)
    increment_counter(:count, row.id)
    row.reload.count
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.summary
    row = find_by(day: today)
    {
      day: today.to_s,
      count: count_today,
      limit: limit,
      remaining: remaining,
      perenual_reported_remaining: row&.reported_remaining,
      perenual_reset_at: row&.reported_reset_at&.utc&.iso8601
    }
  end
end
