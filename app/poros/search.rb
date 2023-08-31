class Search
  attr_accessor :sunlight,
                :hardiness,
                :id,
                :image,
                :name,
                :type

  def initialize(data)
    @sunlight = nil
    @hardiness = nil
    @id = data[:id]
    @image = nil
    @name = data[:common_name]
    @type = data[:type]
  end
end