class CellSerializer
  include JSONAPI::Serializer
  attributes :image, :name, :location_id, :status, :watering, :plant_id, :content_type

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

  # params[:rain_credit] is a callable cell -> rained_at (or nil); see
  # GardenAlerts#rain_credit.
  attribute :next_water_at do |object, params|
    object.next_water_at(rained_at: params[:rain_credit]&.call(object))&.utc&.iso8601
  end

  attribute :needs_water do |object, params|
    object.needs_water?(Time.now, rained_at: params[:rain_credit]&.call(object))
  end
end
