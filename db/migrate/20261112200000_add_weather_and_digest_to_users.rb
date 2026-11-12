class AddWeatherAndDigestToUsers < ActiveRecord::Migration[7.0]
  def change
    # Cached Open-Meteo forecast for the user's coordinates (JSON) and when it
    # was fetched; refreshed every few hours so alerts never hammer the API.
    add_column :users, :weather, :text
    add_column :users, :weather_fetched_at, :datetime
    # The daily email digest is sent at most once per UTC day.
    add_column :users, :last_digest_sent_on, :date
  end
end
