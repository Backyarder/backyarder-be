class UserSerializer
  include JSONAPI::Serializer
  attributes :email, :zip_code, :hardiness_zone
end
