class Plant
  attr_accessor :watering,
                :sunlight,
                :hardiness,
                :image,
                :plant_name,
                :type

  attr_reader :id,
              :plant_id

  def initialize(data)
    @watering = nil
    @sunlight = nil
    @hardiness = nil
    @plant_id = data[:id]
    @image = nil
    @plant_name = data[:common_name]
    @type = nil
    @id = nil
  end
end
