class AddCatalogFieldsToPlantDetails < ActiveRecord::Migration[7.0]
  def change
    # Enough to search and list a plant without its full details: what the
    # species-list call returns. Lets search run against our own table.
    add_column :plant_details, :common_name, :string
    add_column :plant_details, :summary, :text          # JSON: cycle, watering, sunlight, scientific_name
    add_index :plant_details, :common_name

    # The details page image, stored once so details never need re-fetching
    # (Perenual's image links are signed and expire after a day).
    add_column :plant_details, :image, :binary
    add_column :plant_details, :image_content_type, :string

    # Small key/value store, first used for catalogue snapshot progress.
    create_table :settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :settings, :key, unique: true
  end
end
