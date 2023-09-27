class Watering < ActiveRecord::Migration[7.0]
  def change
    add_column :cells, :watering, :integer
  end
end
