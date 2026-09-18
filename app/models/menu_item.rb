class MenuItem < ApplicationRecord
  belongs_to :category, optional: true
  has_many :order_items
  has_many :orders, through: :order_items
  has_many :cart_items

  validates :name, presence: true
  validates :price, numericality: { greater_than: 0 }
end