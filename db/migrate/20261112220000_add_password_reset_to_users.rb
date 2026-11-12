class AddPasswordResetToUsers < ActiveRecord::Migration[7.0]
  def change
    # Only a digest of the emailed reset token is stored; it expires an hour
    # after it was sent and is cleared once used.
    add_column :users, :reset_token_digest, :string
    add_column :users, :reset_sent_at, :datetime
    add_index :users, :reset_token_digest, unique: true
  end
end
