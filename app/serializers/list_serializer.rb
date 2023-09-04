class ListSerializer
  include JSONAPI::Serializer
  attributes :image, :plant_name, :hardiness, :type, :sunlight, :plant_id
end
