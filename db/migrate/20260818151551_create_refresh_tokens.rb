class CreateRefreshTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :refresh_tokens do |t|
      t.references :client, null: false, foreign_key: true
      t.string :token
      t.datetime :expires_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :refresh_tokens, :token, unique: true
  end
end
