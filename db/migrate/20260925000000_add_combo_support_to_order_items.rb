class AddComboSupportToOrderItems < ActiveRecord::Migration[7.0]
  def change
    change_column_null :order_items, :menu_item_id, true

    add_reference :order_items, :combo, foreign_key: true, index: true

    add_check_constraint :order_items,
      "(menu_item_id IS NOT NULL AND combo_id IS NULL) OR (menu_item_id IS NULL AND combo_id IS NOT NULL)",
      name: "order_items_menu_item_xor_combo"
  end
end
