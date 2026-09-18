# db/migrate/20260918186000_add_order_type_fields_to_orders.rb
class AddOrderTypeFieldsToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :order_type, :string, null: false, default: "delivery"
    add_column :orders, :scheduled_at, :datetime

    add_reference :orders, :client_address, null: true, foreign_key: true
    add_reference :orders, :delivery_zone, null: true, foreign_key: true

    change_column_null :orders, :address, true
  end
end
