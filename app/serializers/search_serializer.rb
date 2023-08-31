class SearchSerializer
  include JSONAPI::Serializer
  attributes :image, :name, :hardiness, :id, :type, :sunlight

  # attribute :image do |object|
  #   if object.image == "nil" || nil
  #     "nil"
  #   else
  #     object.image
  #   end
  # end
end
