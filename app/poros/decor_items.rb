class DecorItem
  attr_reader :id,
              :type,
              :attributes

  def initialize(image_url, name, type)
    @image_url = image_url
    @name = name
    @type = type
  end
end