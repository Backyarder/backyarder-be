class CreatePerenualCache < ActiveRecord::Migration[7.0]
  def change
    # One row per Perenual species we've ever looked at. Plant data is static,
    # so it is cached indefinitely; only the signed image URLs inside `details`
    # expire (24h), which is what details_fetched_at tracks.
    create_table :plant_details do |t|
      t.integer :plant_id, null: false
      t.text :details                 # Perenual v2 species/details JSON
      t.text :care                    # care-guide "section" array JSON
      t.datetime :details_fetched_at
      t.binary :thumbnail             # ~10KB JPEG, served from /plants/:id/thumbnail
      t.string :thumbnail_content_type

      t.timestamps
    end
    add_index :plant_details, :plant_id, unique: true

    # Search results by normalized query, refreshed weekly.
    create_table :search_caches do |t|
      t.string :query, null: false
      t.text :results, null: false

      t.timestamps
    end
    add_index :search_caches, :query, unique: true

    # Perenual calls made per UTC day, so we stop before the free-tier limit.
    create_table :api_usages do |t|
      t.date :day, null: false
      t.integer :count, null: false, default: 0

      t.timestamps
    end
    add_index :api_usages, :day, unique: true
  end
end
