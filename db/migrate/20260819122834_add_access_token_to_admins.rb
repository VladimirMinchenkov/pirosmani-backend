class AddAccessTokenToAdmins < ActiveRecord::Migration[7.0]
  def change
    add_column :admins, :access_token, :string
    add_index :admins, :access_token, unique: true
  end
end
