class DecorItem
  attr_reader :image_url, :name, :type, :content_type

  def initialize(attributes)
    @image_url = attributes[:image_url]
    @name = attributes[:name]
    @type = attributes[:type]
    @content_type = attributes[:content_type]
  end
end