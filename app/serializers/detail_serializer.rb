class DetailSerializer
  include JSONAPI::Serializer

  attributes :plant_id,
             :image,
             :name,
             :scientific_name,
             :type,
             :leaf_color,
             :cycle,
             :watering,
             :sunlight,
             :hardiness,
             :pruning_month,
             :attracts,
             :flowering_season,
             :edible_fruit,
             :maintenance,
             :poisonous_to_pets,
             :drought_tolerant,
             :invasive,
             :indoor,
             :section
end
