class AddPositionFieldsToMenuItems < ActiveRecord::Migration[7.0]
  def change
    add_column :menu_items, :position_in_category, :integer
    add_column :menu_items, :position_in_group, :integer

    add_index :menu_items, [:category_id, :position_in_category],
              unique: true,
              where: 'menu_item_group_id IS NULL',
              name: 'idx_menu_items_cat_pos_unique'

    add_index :menu_items, [:menu_item_group_id, :position_in_group],
              unique: true,
              where: 'menu_item_group_id IS NOT NULL',
              name: 'idx_menu_items_group_pos_unique'
  end
end
