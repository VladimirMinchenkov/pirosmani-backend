# app/models/cart_item_addon.rb
class CartItemAddon < ApplicationRecord
  belongs_to :cart_item
  belongs_to :addon, optional: true

  validates :addon_name, presence: true
  validates :addon_price, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  before_validation :snapshot_from_addon, on: :create

  private

  def snapshot_from_addon
    return unless addon

    self.addon_name = addon.name
    self.addon_price = addon.price
  end
end
