# db/migrate/20260918181000_create_product_groups.rb
class CreateProductGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :product_groups do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end
    add_index :product_groups, :slug, unique: true
    add_index :product_groups, :name, unique: true

    add_reference :menu_items, :product_group, null: true, foreign_key: true
    add_column :menu_items, :display_mode, :string, null: false, default: "simple"
  end
end
