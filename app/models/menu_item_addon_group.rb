# app/models/menu_item_addon_group.rb
class MenuItemAddonGroup < ApplicationRecord
  belongs_to :menu_item
  belongs_to :addon_group

  validates :addon_group_id, uniqueness: { scope: :menu_item_id }
end
