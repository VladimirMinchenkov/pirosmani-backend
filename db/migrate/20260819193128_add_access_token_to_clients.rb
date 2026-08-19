class AddAccessTokenToClients < ActiveRecord::Migration[7.0]
  def change
    add_column :clients, :access_token, :string
    add_index :clients, :access_token, unique: true
  end
end
