class Combo < ApplicationRecord
  has_many :combo_items, dependent: :destroy
  accepts_nested_attributes_for :combo_items, allow_destroy: true
  has_many :menu_items, through: :combo_items

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }

  def original_price
    combo_items.sum { |ci| ci.menu_item.price * ci.quantity }
  end

  def savings
    original_price - price
  end
end