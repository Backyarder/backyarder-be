class Search
  attr_accessor :sunlight,
                :hardiness,
                :image,
                :plant_name,
                :type

  attr_reader :id,
              :plant_id

  def initialize(data)
    @sunlight = nil
    @hardiness = nil
    @plant_id = data[:species_id]
    @image = nil
    @plant_name = data[:common_name]
    @type = data[:type]
    @id = nil
  end
end
