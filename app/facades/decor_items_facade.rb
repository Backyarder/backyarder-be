class DecorItemsFacade
  def self.get_decor_items(items)
    items.map do |item|
      image_url = item[:attributes][:image_url]
      name = item[:attributes][:name]
      type = item[:attributes][:type]

      DecorItem.new(image_url, name, type)
    end
  end
end
