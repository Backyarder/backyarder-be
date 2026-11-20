# Aggregate numbers about the app for a quick health check. Counts and dates
# only: no emails, names or anything else that identifies a person, so the
# endpoint can be public.
class AppStats
  def initialize(now: Time.now)
    @now = now
    @today = now.utc.to_date
  end

  def to_h
    {
      generated_at: @now.utc.iso8601,
      accounts: accounts,
      gardens: gardens,
      digest: digest,
      plant_data: plant_data
    }
  end

  private

  def accounts
    last_signup = User.maximum(:created_at)
    last_login = Session.maximum(:created_at)
    {
      total: User.count,
      new_last_7_days: User.where("created_at >= ?", @now - 7 * 86_400).count,
      with_zip_code: User.where.not(zip_code: [nil, ""]).count,
      active_last_7_days: Session.where("created_at >= ?", @now - 7 * 86_400).distinct.count(:user_id),
      last_signup_on: last_signup&.utc&.to_date&.iso8601,
      last_login_on: last_login&.utc&.to_date&.iso8601
    }
  end

  def gardens
    owned = Cell.joins(:garden).where.not(gardens: { user_id: nil })
    {
      with_plants: owned.where.not(name: nil).distinct.count(:garden_id),
      items_placed: owned.where(status: :placed).count,
      items_planted: owned.where(status: :locked).count,
      plants_needing_water: owned.where(status: :locked).select(&:needs_water?).size
    }
  end

  def digest
    last_sent = User.maximum(:last_digest_sent_on)
    {
      sent_today: User.where(last_digest_sent_on: @today).count,
      last_sent_on: last_sent&.iso8601,
      users_ever_emailed: User.where.not(last_digest_sent_on: nil).count
    }
  end

  def plant_data
    {
      plants_searchable: PlantDetail.listed.count,
      catalogue_done: Setting.get(PlantCache::CATALOG_DONE_KEY) == "1",
      perenual_calls_today: ApiUsage.count_today,
      perenual_daily_limit: ApiUsage.limit
    }
  end
end
