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

  def self.remaining
    [limit - count_today, 0].max
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
    { day: today.to_s, count: count_today, limit: limit, remaining: remaining }
  end
end
