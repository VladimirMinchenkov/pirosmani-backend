# db/migrate/20260918182000_add_figma_fields_to_menu_items.rb
class AddFigmaFieldsToMenuItems < ActiveRecord::Migration[7.0]
  def change
    add_column :menu_items, :weight_label, :string
    add_column :menu_items, :calories, :integer
    add_column :menu_items, :allergens, :jsonb, default: [], null: false
    add_column :menu_items, :sku, :string
    add_column :menu_items, :position, :integer, default: 0, null: false

    add_index :menu_items, :sku, unique: true
    add_index :menu_items, :position
  end
end
