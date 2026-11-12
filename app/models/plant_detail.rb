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
      has_image: thumbnail?,
      image_path: s[:image_path]  # frontend-hosted picture, when the plant is a stock snapshot
    }
  end

  STOCK_INDEX = "mock_json/index.json".freeze
  STOCK_DETAILS_DIR = "mock_json/details".freeze

  # Loads the stock snapshots (mock_json) into this table so they are part of
  # local search. Idempotent; runs with the seeds on every deploy.
  def self.import_stock!
    index = JSON.parse(File.read(STOCK_INDEX), symbolize_names: true)[:data]
    imported = 0
    index.each do |entry|
      id = entry[:id]
      path = File.join(STOCK_DETAILS_DIR, "#{id}.json")
      next unless File.exist?(path)

      data = JSON.parse(File.read(path), symbolize_names: true)
      record = find_or_initialize_by(plant_id: id)
      record.details ||= JSON.generate(data)
      record.details_fetched_at ||= Time.now
      record.common_name ||= data[:common_name] || entry[:common_name]
      thumb = data.dig(:default_image, :thumbnail)
      record.summary = JSON.generate(record.summary_hash.merge(
        cycle: data[:cycle], watering: data[:watering], sunlight: data[:sunlight] || [],
        scientific_name: data[:scientific_name], image_path: (thumb if thumb.to_s.start_with?("/images/"))
      ))
      if record.changed?
        record.save!
        imported += 1
      end
    end
    imported
  end
end
