class DecorItemsFacade
  def self.get_decor_items(query)
    images = UnsplashService.get_images(query)

    if images[:results].empty?
      nil
    else
      image_data = images[:results].first

      image_url = image_data[:urls][:regular] # or :full or :small based on the size you want
      name = image_data[:alt_description] || "Unknown Decor" 
      type = "barrier"

      DecorItem.new(image_url, name, type)
    end
  end
end
