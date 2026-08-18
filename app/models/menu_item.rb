class MenuItem < ApplicationRecord
  has_many :order_items
  has_many :orders, through: :order_items

  validates :name, presence: true
  validates :price, numericality: { greater_than: 0 }
end