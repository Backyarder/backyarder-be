class DecorItemsFacade
  def self.get_decor_items(items)
    items.map do |item|
      attributes = {
        image_url: item[:attributes][:image_url],
        name: item[:attributes][:name],
        type: item[:attributes][:type]
      }
      DecorItem.new(attributes)
    end
  end
end
