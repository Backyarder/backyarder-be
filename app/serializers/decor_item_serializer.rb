class DecorItemSerializer
  include JSONAPI::Serializer

  set_id :id
  set_type :list
  attributes :image_url, :name, :type, :content_type
end