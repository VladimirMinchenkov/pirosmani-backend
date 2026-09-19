class RenameProductGroupsToMenuItemGroups < ActiveRecord::Migration[7.0]
  def change
    rename_table :product_groups, :menu_item_groups
    rename_column :menu_items, :product_group_id, :menu_item_group_id
  end
end
