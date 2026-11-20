# A gardener's own watering interval for one cell (nil = automatic plan,
# 0 = never remind).
class AddWateringOverrideDaysToCells < ActiveRecord::Migration[7.0]
  def change
    add_column :cells, :watering_override_days, :integer
  end
end
