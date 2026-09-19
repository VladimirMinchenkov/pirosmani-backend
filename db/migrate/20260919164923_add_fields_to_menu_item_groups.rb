class AddFieldsToMenuItemGroups < ActiveRecord::Migration[7.0]
  def change
    add_column :menu_item_groups, :category_id, :bigint
    add_column :menu_item_groups, :position_in_category, :integer, default: 0, null: false
    add_column :menu_item_groups, :min_total_quantity, :integer
    add_column :menu_item_groups, :description, :text
    add_column :menu_item_groups, :image_url, :string
    add_column :menu_item_groups, :available, :boolean, default: true, null: false

    add_index :menu_item_groups, [:category_id, :position_in_category], unique: true,
              name: 'idx_menu_item_groups_cat_pos_unique'
  end
end
