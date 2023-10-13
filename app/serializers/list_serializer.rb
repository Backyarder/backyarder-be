class ListSerializer
  include JSONAPI::Serializer
  attributes :image, :name, :hardiness, :type, :sunlight, :watering, :plant_id
end
