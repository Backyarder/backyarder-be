# Built-in plants now have photos (/images/plants/<id>.jpg). Cells placed
# before that still point at the old SVG icons; switch them over.
class UsePhotosForPlacedBuiltIns < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE cells
      SET image = '/images/plants/' || CAST(plant_id AS TEXT) || '.jpg'
      WHERE plant_id BETWEEN 900001 AND 999999
        AND image LIKE '/images/%.svg'
    SQL
  end

  def down
    # The SVG paths aren't recoverable from the cell alone; leave the photos.
  end
end
