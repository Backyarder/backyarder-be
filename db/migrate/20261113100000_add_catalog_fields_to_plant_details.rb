class AddCatalogFieldsToPlantDetails < ActiveRecord::Migration[7.0]
  def up
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

    # Plants we already hold details for become searchable right away.
    # (A local model class: app models are not loaded while migrating.)
    plant_details = Class.new(ActiveRecord::Base) { self.table_name = "plant_details" }
    plant_details.reset_column_information
    plant_details.where(common_name: nil).where.not(details: nil).find_each do |record|
      name = JSON.parse(record.details)["common_name"]
      record.update_columns(common_name: name) if name
    end
  end

  def down
    drop_table :settings
    remove_column :plant_details, :image_content_type
    remove_column :plant_details, :image
    remove_index :plant_details, :common_name
    remove_column :plant_details, :summary
    remove_column :plant_details, :common_name
  end
end
