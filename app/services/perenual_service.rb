class PerenualService
  def conn
    Faraday.new("https://perenual.com/api/")
  end

  def get_url(url)
    response = conn.get(url)
    JSON.parse(response.body, symbolize_names: true)
  end

  def search(plant_name)
    get_url("species-care-guide-list?q=#{plant_name}&key=#{ENV['PERENUAL_API_KEY']}")
  end

  def detail_search(plant_id)
    get_url("species/details/#{plant_id}?key=#{ENV['PERENUAL_API_KEY']}")
  end
end
