class AddCareTimestampsToCells < ActiveRecord::Migration[7.0]
  def up
    # updated_at changes on every edit (moving, disabling, re-saving), so it is
    # a poor "last watered" signal. Track care events explicitly.
    add_column :cells, :planted_at, :datetime
    add_column :cells, :last_watered_at, :datetime

    # Plants that are already in the ground: treat their last edit as the last
    # watering so alerts start from a sensible point rather than firing at once.
    execute "UPDATE cells SET planted_at = updated_at, last_watered_at = updated_at WHERE status = 3 AND planted_at IS NULL"
  end

  def down
    remove_column :cells, :last_watered_at
    remove_column :cells, :planted_at
  end
end
