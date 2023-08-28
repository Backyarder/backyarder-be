require "./app/models/cell"

Cell.destroy_all

("A".."J").each do |letter|
  10.times do |index|
    cell = "#{letter}#{index + 1}"
    Cell.create!(location_id: cell, status: 0)
  end
end
