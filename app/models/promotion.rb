class Promotion < ApplicationRecord
  belongs_to :menu_item

  validates :menu_item_id, uniqueness: { message: "уже имеет скидку" }

  DISCOUNT_TYPES = %w[fixed percent].freeze

  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }
  validate :discount_value_limits

  scope :active, -> { where(active: true) }
  scope :current, -> {
    active.where("starts_at IS NULL OR starts_at <= ?", Time.current)
          .where("ends_at IS NULL OR ends_at >= ?", Time.current)
  }

  def apply(price)
    return price unless active?
    return price if starts_at && Time.current < starts_at
    return price if ends_at && Time.current > ends_at

    case discount_type
    when "fixed" then [price - discount_value, 0].max
    when "percent" then (price * (1 - discount_value / 100.0)).round(2)
    else price
    end
  end

  private

  def discount_value_limits
    if discount_type == "percent" && discount_value.to_f > 100
      errors.add(:discount_value, "не может быть больше 100%")
    end
    if discount_type == "fixed" && menu_item && discount_value.to_f >= menu_item.price.to_f
      errors.add(:discount_value, "не может быть больше или равно цене блюда")
    end
  end
end