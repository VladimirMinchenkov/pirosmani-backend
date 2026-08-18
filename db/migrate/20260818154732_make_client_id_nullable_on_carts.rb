class MakeClientIdNullableOnCarts < ActiveRecord::Migration[7.0]
  def change
    change_column_null :carts, :client_id, true
  end
end