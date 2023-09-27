class CellSerializer
  include JSONAPI::Serializer
  attributes :image, :plant_name, :location_id, :status, :watering, :plant_id

  attribute :updated_at do |object|
    object.updated_at.strftime("%m/%d/%Y %k:%M")
  end
end
