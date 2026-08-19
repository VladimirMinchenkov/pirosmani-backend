class RemovePhoneFromOrders < ActiveRecord::Migration[7.0]
  def change
    remove_column :orders, :phone
  end
end
