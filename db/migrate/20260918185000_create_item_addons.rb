# db/migrate/20260918185000_create_item_addons.rb
class CreateItemAddons < ActiveRecord::Migration[7.0]
  def change
    create_table :cart_item_addons do |t|
      t.references :cart_item, null: false, foreign_key: true
      t.references :addon, null: true, foreign_key: true
      t.string :addon_name, null: false
      t.decimal :addon_price, precision: 10, scale: 2, default: "0.0", null: false
      t.integer :quantity, default: 1, null: false

      t.timestamps
    end

    create_table :order_item_addons do |t|
      t.references :order_item, null: false, foreign_key: true
      t.references :addon, null: true, foreign_key: true
      t.string :addon_name, null: false
      t.decimal :addon_price, precision: 10, scale: 2, default: "0.0", null: false
      t.integer :quantity, default: 1, null: false

      t.timestamps
    end
  end
end
