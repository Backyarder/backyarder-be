# Looks up a US zip code's USDA hardiness zone and coordinates via phzmapi.org
# (free, no key). Returns nil for an unknown zip or when the service is down.
class HardinessService
  BASE_URL = "https://phzmapi.org/".freeze

  def lookup(zip_code)
    zip = zip_code.to_s.strip
    return nil unless zip.match?(/\A\d{5}\z/)

    response = Faraday.new(BASE_URL).get("#{zip}.json")
    return nil unless response.success?

    data = JSON.parse(response.body, symbolize_names: true)
    return nil if data[:zone].to_s.empty?

    {
      zone: data[:zone],
      latitude: data.dig(:coordinates, :lat)&.to_f,
      longitude: data.dig(:coordinates, :lon)&.to_f
    }
  rescue Faraday::Error, JSON::ParserError
    nil
  end
end
