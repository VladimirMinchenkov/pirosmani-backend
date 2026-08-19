class Order < ApplicationRecord
  belongs_to :delivery_zone
  belongs_to :client

  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  validates :address, presence: true

  enum status: { pending: 0, confirmed: 1, cooking: 2, delivering: 3, done: 4, cancelled: 5 }
end