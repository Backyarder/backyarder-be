class CellSerializer
  include JSONAPI::Serializer
  attributes :image, :name, :location_id, :status, :watering, :plant_id, :content_type

  attribute :updated_at do |object|
    object.updated_at.strftime("%m/%d/%Y %k:%M")
  end
end
