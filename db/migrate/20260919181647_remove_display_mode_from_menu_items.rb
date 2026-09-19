class RemoveDisplayModeFromMenuItems < ActiveRecord::Migration[7.0]
  def change
    remove_column :menu_items, :display_mode, :string, default: "simple", null: false
  end
end
