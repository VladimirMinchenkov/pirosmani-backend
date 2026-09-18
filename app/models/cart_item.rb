# app/models/cart_item.rb
class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :menu_item
  has_many :cart_item_addons, dependent: :destroy

  validates :quantity, numericality: { greater_than: 0 }
  validates :menu_item_id, uniqueness: { scope: :cart_id }
end
