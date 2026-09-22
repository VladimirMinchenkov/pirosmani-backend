class CreateOrderPromotions < ActiveRecord::Migration[7.0]
  def change
    create_table :order_promotions do |t|
      t.decimal :min_amount, null: false, precision: 10, scale: 2
      t.string :discount_type, null: false  # "fixed" или "percent"
      t.decimal :discount_value, null: false, precision: 10, scale: 2
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :order_promotions, :active
  end
end