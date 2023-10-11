class CreateCellsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :cells do |t|
      t.string :plant_name
      t.string :location_id
      t.string :image
      t.integer :status
      t.integer :plant_id

      t.timestamps
    end
  end
end
