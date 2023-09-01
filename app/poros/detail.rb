class Detail
  attr_accessor :section

  attr_reader :id,
              :plant_id,
              :image,
              :common_name,
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
              :indoor

  def initialize(data)
    @plant_id = data[:id]
    @image = data[:default_image][:regular_url]
    @common_name = data[:common_name]
    @scientific_name = data[:scientific_name]
    @type = data[:type]
    @leaf_color = data[:leaf_color]
    @cycle = data[:cycle]
    @watering = data[:watering]
    @sunlight = data[:sunlight]
    @hardiness = data[:hardiness]
    @section = nil
    @pruning_month = data[:pruning_month]
    @attracts = data[:attracts]
    @flowering_season = data[:flowering_season] || []
    @edible_fruit = data[:edible_fruit]
    @maintenance = data[:maintenance]
    @poisonous_to_pets = !data[:poisonous_to_pets].zero?
    @drought_tolerant = data[:drought_tolerant]
    @invasive = data[:invasive]
    @indoor = data[:indoor]
    @id = nil
  end
end
