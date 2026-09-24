class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item, optional: true
  belongs_to :combo, optional: true
  has_many :order_item_addons, dependent: :destroy

  validates :quantity, numericality: { greater_than: 0 }
  validate :exactly_one_of_menu_item_or_combo

  # Название позиции независимо от того, блюдо это или комбо
  def display_name
    menu_item&.name || combo&.name
  end

  private

  def exactly_one_of_menu_item_or_combo
    if menu_item_id.present? == combo_id.present?
      errors.add(:base, "Order item must have exactly one of menu_item or combo")
    end
  end
end
