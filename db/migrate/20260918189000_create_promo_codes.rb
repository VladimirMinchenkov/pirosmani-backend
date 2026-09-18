# db/migrate/20260918189000_create_promo_codes.rb
class CreatePromoCodes < ActiveRecord::Migration[7.0]
  def change
    create_table :promo_codes do |t|
      t.string :code, null: false
      t.string :discount_type, null: false, default: "fixed"
      t.decimal :discount_value, precision: 10, scale: 2, null: false
      t.decimal :min_order_price, precision: 10, scale: 2, default: 0.0
      t.datetime :active_from
      t.datetime :active_until
      t.integer :usage_limit
      t.integer :usage_count, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :promo_codes, :code, unique: true
    add_reference :orders, :promo_code, null: true, foreign_key: true

    add_column :clients, :bonus_points, :integer, default: 0, null: false
  end
end