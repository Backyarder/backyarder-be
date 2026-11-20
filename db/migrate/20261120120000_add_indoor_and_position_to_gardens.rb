# Gardens become named areas: an indoor flag (no rain credit, no frost
# worries) and an order for the area tabs.
class AddIndoorAndPositionToGardens < ActiveRecord::Migration[7.0]
  def change
    add_column :gardens, :indoor, :boolean, default: false, null: false
    add_column :gardens, :position, :integer, default: 0, null: false
  end
end
