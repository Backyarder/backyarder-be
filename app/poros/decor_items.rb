class DecorItem
  attr_reader :id,
              :type,
              :attributes

  def initialize(image_link, name, decor_type)
    @id = nil
    @type = "list"
    @attributes = {
      image: image_link,
      name: name,
      type: decor_type
    }
  end
end