class CreatePromotions < ActiveRecord::Migration[7.0]
  def change
    create_table :promotions do |t|
      t.references :menu_item, null: false, foreign_key: true
      t.string :discount_type, null: false  # "fixed" или "percent"
      t.decimal :discount_value, null: false, precision: 10, scale: 2
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :promotions, :active
  end
end