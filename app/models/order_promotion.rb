class OrderPromotion < ApplicationRecord
  DISCOUNT_TYPES = %w[fixed percent].freeze

  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }
  validates :min_amount, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :current, -> {
    active.where("starts_at IS NULL OR starts_at <= ?", Time.current)
          .where("ends_at IS NULL OR ends_at >= ?", Time.current)
  }

  def apply(order_total)
    return 0 unless active?
    return 0 if starts_at && Time.current < starts_at
    return 0 if ends_at && Time.current > ends_at
    return 0 if order_total < min_amount

    case discount_type
    when "fixed" then [discount_value, order_total].min
    when "percent" then (order_total * discount_value / 100.0).round(2)
    else 0
    end
  end
end