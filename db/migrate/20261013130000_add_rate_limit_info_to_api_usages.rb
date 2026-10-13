class AddRateLimitInfoToApiUsages < ActiveRecord::Migration[7.0]
  def change
    # What Perenual itself last reported (X-RateLimit-* headers), when present.
    # Its window is rolling 24h per caller, so this is more accurate than our
    # per-day tally when available.
    add_column :api_usages, :reported_remaining, :integer
    add_column :api_usages, :reported_reset_at, :datetime
  end
end
