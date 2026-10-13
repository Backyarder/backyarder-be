class PlantDetail < ActiveRecord::Base
  # Perenual signs image URLs for 24 hours; refresh a little before that.
  IMAGE_TTL = 23 * 60 * 60

  validates :plant_id, presence: true, uniqueness: true

  def details_hash
    details && JSON.parse(details, symbolize_names: true)
  end

  def care_sections
    care && JSON.parse(care, symbolize_names: true)
  end

  def details_fresh?
    details.present? && details_fetched_at.present? && details_fetched_at > Time.now - IMAGE_TTL
  end

  def thumbnail?
    thumbnail.present?
  end
end
