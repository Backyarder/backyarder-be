class Cell < ActiveRecord::Base
  DAY = 24 * 60 * 60
  MAX_OVERRIDE_DAYS = 60

  belongs_to :garden, optional: true # nil only for pre-accounts rows in tests

  validates :location_id, presence: true
  validates :status, presence: true

  enum status: { empty: 0, placed: 1, disabled: 2, locked: 3 }
  enum watering: { None: 0, Minimum: 1, Average: 2, Frequent: 3 }
  enum content_type: { Plant: "Plant", Decor: "Decor" }

  # nil = automatic plan, 0 = never remind, otherwise every N days.
  validates :watering_override_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_OVERRIDE_DAYS }, allow_nil: true

  # An emptied cell forgets its custom schedule (update_all callers use CLEARED).
  before_save { self.watering_override_days = nil if empty? }

  # --- watering plan (see WateringPlan) ------------------------------------

  # Profile of the plant in this cell (type, cycle, drought_tolerant,
  # collection, watering), or nil when nothing is known. Looked up once per
  # plant_id unless WateringPlan.preload already supplied it.
  def plant_profile
    unless defined?(@plant_profile) && @plant_profile_for == plant_id
      @plant_profile = WateringPlan.profiles_for([plant_id])[plant_id]
      @plant_profile_for = plant_id
    end
    @plant_profile
  end

  def plot_indoor?
    @plot_indoor.nil? ? garden&.indoor? == true : @plot_indoor
  end

  def preload_watering(profile, indoor)
    @plant_profile = profile
    @plant_profile_for = plant_id
    @plot_indoor = indoor
  end

  # Memoized per day and per the attributes it depends on, since the
  # serializer asks for several of its fields.
  def watering_plan(now = Time.now)
    key = [plant_profile, plot_indoor?, watering, watering_override_days, planted_at, now.to_date]
    @watering_plan = [key, WateringPlan.for(self, now: now)] unless @watering_plan&.first == key
    @watering_plan.last
  end

  # Seconds between waterings, or nil when this cell gets no reminders.
  def watering_interval(now = Time.now)
    days = watering_plan(now)[:days]
    days && days * DAY
  end

  # Only plants that are actually in the ground are on a schedule.
  def tracks_watering?(now = Time.now)
    locked? && content_type == "Plant" && !watering_interval(now).nil?
  end

  def last_care_at
    last_watered_at || planted_at
  end

  # rained_at: when enough rain fell to count as a watering (outdoor plants
  # only; the caller decides). The later of that and the last watering wins.
  def next_water_at(rained_at: nil, now: Time.now)
    interval = locked? && content_type == "Plant" && last_care_at && watering_interval(now)
    return nil unless interval

    base = [last_care_at, rained_at].compact.max
    base + interval
  end

  def needs_water?(now = Time.now, rained_at: nil)
    due = next_water_at(rained_at: rained_at, now: now)
    !due.nil? && due <= now
  end

  # Marks the plant as in the ground. Planting counts as a watering.
  def plant!(now = Time.now)
    update!(status: :locked, planted_at: planted_at || now, last_watered_at: now)
  end

  def water!(now = Time.now)
    update!(last_watered_at: now)
  end

  # Attributes that make a cell empty; shared by clear!, DELETE /garden and DELETE /all.
  CLEARED = { status: :empty, plant_id: nil, image: nil, name: nil, content_type: nil,
              watering: nil, planted_at: nil, last_watered_at: nil, watering_override_days: nil }.freeze

  def clear!
    update!(CLEARED)
  end
end
