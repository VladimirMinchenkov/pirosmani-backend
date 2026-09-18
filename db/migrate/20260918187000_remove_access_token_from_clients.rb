# db/migrate/20260918187000_remove_access_token_from_clients.rb
class RemoveAccessTokenFromClients < ActiveRecord::Migration[7.0]
  def change
    remove_index :clients, :access_token, if_exists: true
    remove_column :clients, :access_token, :string
  end
end
