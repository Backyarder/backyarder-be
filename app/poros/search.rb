class Search
  attr_accessor :watering,
                :sunlight,
                :hardiness,
                :image,
                :name,
                :type,
                :content_type

  attr_reader :id,
              :plant_id

  def initialize(data)
    @watering = nil
    @sunlight = nil
    @hardiness = nil
    @plant_id = data[:species_id]
    @image = nil
    @name = data[:common_name]
    @type = data[:type]
    @id = nil
    @content_type = nil
  end
end
