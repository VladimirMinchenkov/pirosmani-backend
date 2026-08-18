class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|
      t.string :status
      t.string :address
      t.string :phone
      t.decimal :total_price
      t.decimal :delivery_price

      t.timestamps
    end
  end
end
