class SearchSerializer
  include JSONAPI::Serializer
  attributes :image, :name, :hardiness, :type, :sunlight, :plant_id
end
