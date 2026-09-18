class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item
  has_many :order_item_addons, dependent: :destroy

  validates :quantity, numericality: { greater_than: 0 }
end
