class DecorItem
  attr_accessor :image_url, :name, :type, :content_type

  attr_reader :id

  def initialize(attributes)
    @id = nil
    @image_url = attributes[:attributes][:image_url]
    @name = attributes[:attributes][:name]
    @type = attributes[:attributes][:type]
    @content_type = attributes[:attributes][:content_type]
  end
end
