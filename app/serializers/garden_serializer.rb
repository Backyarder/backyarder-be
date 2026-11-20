class GardenSerializer
  include JSONAPI::Serializer

  set_type :garden
  attributes :name, :indoor, :position

  # Counts for the area tabs (params[:counts] = { garden_id => {...} }).
  attribute :plant_count do |object, params|
    params.dig(:counts, object.id, :plants) || 0
  end

  attribute :needs_water_count do |object, params|
    params.dig(:counts, object.id, :needs_water) || 0
  end
end
