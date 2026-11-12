class AddCoordinatesToUsers < ActiveRecord::Migration[7.0]
  def change
    # From the zip code lookup; used for weather-aware alerts.
    add_column :users, :latitude, :decimal, precision: 9, scale: 6
    add_column :users, :longitude, :decimal, precision: 9, scale: 6
  end
end
