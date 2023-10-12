class CreateCellsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :cells do |t|
      t.string :name
      t.string :location_id
      t.string :image
      t.integer :status
      t.integer :plant_id
      t.string :content_type, default: "None"

      t.timestamps
    end
  end
end
