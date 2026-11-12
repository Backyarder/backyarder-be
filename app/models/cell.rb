class Cell < ActiveRecord::Base
  # How often a planted (locked) plant wants water, by Perenual's watering
  # level. "None" and decor items are never due.
  WATERING_INTERVAL_DAYS = { "Frequent" => 2, "Average" => 5, "Minimum" => 10 }.freeze

  belongs_to :garden, optional: true # nil only for pre-accounts rows in tests

  validates :location_id, presence: true
  validates :status, presence: true

  enum status: { empty: 0, placed: 1, disabled: 2, locked: 3 }
  enum watering: { None: 0, Minimum: 1, Average: 2, Frequent: 3 }
  enum content_type: { Plant: "Plant", Decor: "Decor" }

  # --- care tracking -------------------------------------------------------

  # Seconds between waterings, or nil when this cell never needs water.
  def watering_interval
    days = WATERING_INTERVAL_DAYS[watering]
    days && days * 24 * 60 * 60
  end

  # Only plants that are actually in the ground are on a schedule.
  def tracks_watering?
    locked? && content_type == "Plant" && !watering_interval.nil?
  end

  def last_care_at
    last_watered_at || planted_at
  end

  def next_water_at
    return nil unless tracks_watering? && last_care_at

    last_care_at + watering_interval
  end

  def needs_water?(now = Time.now)
    due = next_water_at
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
              watering: nil, planted_at: nil, last_watered_at: nil }.freeze

  def clear!
    update!(CLEARED)
  end
end
