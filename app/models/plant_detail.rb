class PlantDetail < ActiveRecord::Base
  validates :plant_id, presence: true, uniqueness: true

  scope :listed, -> { where.not(common_name: nil) }

  def details_hash
    details && JSON.parse(details, symbolize_names: true)
  end

  def care_sections
    care && JSON.parse(care, symbolize_names: true)
  end

  def summary_hash
    summary ? JSON.parse(summary, symbolize_names: true) : {}
  end

  # Plant data is static: once we have details we never fetch them again.
  def details?
    details.present?
  end

  def thumbnail?
    thumbnail.present?
  end

  def image?
    image.present?
  end

  def name
    common_name || details_hash&.dig(:common_name)
  end

  # The shape a search result has, built from whatever we know locally.
  def listing
    d = details_hash || {}
    s = summary_hash
    {
      plant_id: plant_id,
      name: name,
      cycle: s[:cycle] || d[:cycle],
      watering: s[:watering] || d[:watering],
      sunlight: s[:sunlight] || d[:sunlight] || [],
      type: d[:type],
      hardiness: d[:hardiness],
      has_image: thumbnail?
    }
  end
end
