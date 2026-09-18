# app/models/addon.rb
class Addon < ApplicationRecord
  belongs_to :addon_group
  has_many :cart_item_addons, dependent: :nullify
  has_many :order_item_addons, dependent: :nullify

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
