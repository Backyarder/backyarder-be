# Plots can be any size up to 15 x 15; existing ones stay 10 x 10.
class AddSizeToGardens < ActiveRecord::Migration[7.0]
  def change
    add_column :gardens, :rows, :integer, default: 10, null: false
    add_column :gardens, :cols, :integer, default: 10, null: false
  end
end
