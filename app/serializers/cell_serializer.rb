class CellSerializer
  include JSONAPI::Serializer
  attributes :image, :name, :location_id, :status, :watering, :plant_id, :content_type, :watering_override_days

  # Loads every cell's plant profile in one query before serializing (see
  # WateringPlan.preload). A relation is loaded once and serialized as-is.
  def initialize(resource, options = {})
    resource = resource.to_a if resource.is_a?(ActiveRecord::Relation)
    WateringPlan.preload(resource)
    super
  end

  attribute :updated_at do |object|
    object.updated_at.strftime("%m/%d/%Y %k:%M")
  end

  # Care tracking (ISO 8601 UTC, or null). needs_water is computed server-side
  # so every client agrees and it survives page reloads.
  attribute :planted_at do |object|
    object.planted_at&.utc&.iso8601
  end

  attribute :last_watered_at do |object|
    object.last_watered_at&.utc&.iso8601
  end

  # The cell's watering plan: days between waterings (null = no reminders),
  # a short reason, "auto" or "custom", and whether rain counts as a watering.
  attribute :watering_days do |object|
    object.watering_plan[:days]
  end

  attribute :watering_reason do |object|
    object.watering_plan[:reason]
  end

  attribute :watering_source do |object|
    object.watering_plan[:source]
  end

  # What the automatic plan would be, for "Auto (every N days)" while a
  # custom schedule is set.
  attribute :watering_auto_days do |object|
    object.watering_plan[:auto_days]
  end

  attribute :watering_rain_resets do |object|
    object.watering_plan[:rain_resets]
  end

  # params[:rain_credit] is a callable cell -> rained_at (or nil); see
  # GardenAlerts#rain_credit.
  attribute :next_water_at do |object, params|
    object.next_water_at(rained_at: params[:rain_credit]&.call(object))&.utc&.iso8601
  end

  attribute :needs_water do |object, params|
    object.needs_water?(Time.now, rained_at: params[:rain_credit]&.call(object))
  end
end
