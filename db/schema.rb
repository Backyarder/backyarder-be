# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_11_12_150100) do
  create_table "api_usages", force: :cascade do |t|
    t.date "day", null: false
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reported_remaining"
    t.datetime "reported_reset_at"
    t.index ["day"], name: "index_api_usages_on_day", unique: true
  end

  create_table "cells", force: :cascade do |t|
    t.string "name"
    t.string "location_id"
    t.string "image"
    t.integer "status"
    t.integer "plant_id"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "watering"
    t.integer "garden_id"
    t.datetime "planted_at"
    t.datetime "last_watered_at"
    t.index ["garden_id", "location_id"], name: "index_cells_on_garden_id_and_location_id", unique: true
    t.index ["garden_id"], name: "index_cells_on_garden_id"
  end

  create_table "gardens", force: :cascade do |t|
    t.integer "user_id"
    t.string "name", default: "My Garden", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_gardens_on_user_id"
  end

  create_table "plant_details", force: :cascade do |t|
    t.integer "plant_id", null: false
    t.text "details"
    t.text "care"
    t.datetime "details_fetched_at"
    t.binary "thumbnail"
    t.string "thumbnail_content_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plant_id"], name: "index_plant_details_on_plant_id", unique: true
  end

  create_table "search_caches", force: :cascade do |t|
    t.string "query", null: false
    t.text "results", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["query"], name: "index_search_caches_on_query", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "zip_code"
    t.string "hardiness_zone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "plant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "plant_id"], name: "index_wishlist_items_on_user_id_and_plant_id", unique: true
    t.index ["user_id"], name: "index_wishlist_items_on_user_id"
  end

  add_foreign_key "cells", "gardens"
  add_foreign_key "gardens", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "wishlist_items", "users"
end
