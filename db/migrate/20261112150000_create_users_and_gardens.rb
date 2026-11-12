class CreateUsersAndGardens < ActiveRecord::Migration[7.0]
  def up
    # Accounts. Passwords are bcrypt digests (has_secure_password).
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :zip_code
      t.string :hardiness_zone

      t.timestamps
    end
    add_index :users, :email, unique: true

    # Server-side login sessions. Only a SHA-256 digest of the token is stored,
    # so a leaked database row cannot be replayed. Logout deletes the row.
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true

    # A garden is a 10x10 grid of cells. user_id is nil for the pre-accounts
    # shared garden so existing data keeps working until everyone has logged in.
    create_table :gardens do |t|
      t.references :user, foreign_key: true
      t.string :name, null: false, default: "My Garden"

      t.timestamps
    end

    create_table :wishlist_items do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :plant_id, null: false

      t.timestamps
    end
    add_index :wishlist_items, [:user_id, :plant_id], unique: true

    add_reference :cells, :garden, foreign_key: true
    add_index :cells, [:garden_id, :location_id], unique: true

    # Attach the existing cells to a legacy shared garden so nothing is orphaned.
    return unless select_value("SELECT COUNT(*) FROM cells").to_i.positive?

    now = quote(Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"))
    execute "INSERT INTO gardens (name, created_at, updated_at) VALUES ('Shared garden', #{now}, #{now})"
    garden_id = select_value("SELECT MAX(id) FROM gardens").to_i
    execute "UPDATE cells SET garden_id = #{garden_id} WHERE garden_id IS NULL"
  end

  def down
    remove_index :cells, [:garden_id, :location_id]
    remove_reference :cells, :garden, foreign_key: true
    drop_table :wishlist_items
    drop_table :gardens
    drop_table :sessions
    drop_table :users
  end
end
