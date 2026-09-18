# db/migrate/20260918183000_create_addon_groups.rb
class CreateAddonGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :addon_groups do |t|
      t.string :name, null: false
      t.integer :min_selection, default: 0, null: false
      t.integer :max_selection
      t.boolean :required, default: false, null: false

      t.timestamps
    end
    add_index :addon_groups, :name, unique: true

    create_table :addons do |t|
      t.references :addon_group, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, default: "0.0", null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    create_table :menu_item_addon_groups do |t|
      t.references :menu_item, null: false, foreign_key: true
      t.references :addon_group, null: false, foreign_key: true

      t.timestamps
    end
    add_index :menu_item_addon_groups, %i[menu_item_id addon_group_id],
              unique: true, name: "idx_menu_item_addon_groups_unique"
  end
end
