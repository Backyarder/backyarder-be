require "./app/models/cell"
require "./app/models/plant_detail"

# Seeds run on every production deploy, so only build the garden when it is
# empty. Set FORCE_SEED=1 to wipe and rebuild it on purpose.
if Cell.exists? && !ENV["FORCE_SEED"]
  puts "Garden already seeded (#{Cell.count} cells); skipping. Set FORCE_SEED=1 to reset."
else
  Cell.destroy_all

  ("A".."J").each do |letter|
    10.times do |index|
      cell = "#{letter}#{index + 1}"
      Cell.create!(location_id: cell, status: :empty)
    end
  end

  puts "Seeded #{Cell.count} garden cells."
end

# Stock plant snapshots become searchable rows; idempotent.
puts "Imported #{PlantDetail.import_stock!} stock plant snapshots into the search index."
