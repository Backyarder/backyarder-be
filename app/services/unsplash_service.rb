class UnsplashService
  def self.get_images(query)
    response = conn.get("/search/photos?query=#{query}")
    JSON.parse(response.body, symbolize_names: true)
  end

  def self.conn
    Faraday.new('https://api.unsplash.com') do |f|
      f.params['client_id'] = ENV['UNSPLASH_ACCESS_KEY']
    end
  end
end