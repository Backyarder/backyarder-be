class DecorItem
  attr_reader :image_url, :name, :type

  def initialize(attributes)
    @image_url = attributes[:image_url]
    @name = attributes[:name]
    @type = attributes[:type]
  end
end