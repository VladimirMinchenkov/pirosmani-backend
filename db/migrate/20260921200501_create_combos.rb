class CreateCombos < ActiveRecord::Migration[7.0]
  def change
    create_table :combos do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :price, null: false, precision: 10, scale: 2
      t.string :image_url
      t.boolean :active, default: true
      t.timestamps
    end

    create_table :combo_items do |t|
      t.references :combo, null: false, foreign_key: true
      t.references :menu_item, null: false, foreign_key: true
      t.integer :quantity, default: 1
      t.timestamps
    end
  end
end