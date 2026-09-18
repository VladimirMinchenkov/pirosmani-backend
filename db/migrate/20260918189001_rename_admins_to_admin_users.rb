class RenameAdminsToAdminUsers < ActiveRecord::Migration[7.0]
  def change
    rename_table :admins, :admin_users
  end
end
