class ListSerializer
  include JSONAPI::Serializer
  attributes :image, :plant_name, :hardiness, :type, :sunlight, :watering, :plant_id
end
