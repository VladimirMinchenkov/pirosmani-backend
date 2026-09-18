# app/models/promo_code.rb
class PromoCode < ApplicationRecord
  DISCOUNT_TYPES = %w[fixed percent].freeze

  has_many :orders

  validates :code, presence: true, uniqueness: true
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, numericality: { greater_than: 0 }
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :active_now, -> {
    where(active: true)
      .where("active_from IS NULL OR active_from <= ?", Time.current)
      .where("active_until IS NULL OR active_until > ?", Time.current)
  }

  def usable?
    active? && !expired? && !depleted? && started?
  end

  def depleted?
    usage_limit.present? && usage_count >= usage_limit
  end

  def expired?
    active_until.present? && active_until <= Time.current
  end

  def started?
    active_from.nil? || active_from <= Time.current
  end

  def apply_to(total)
    case discount_type
    when "fixed" then [total - discount_value, 0].max
    when "percent" then total * (1 - discount_value / 100.0)
    else total
    end
  end

  def increment_usage!
    increment!(:usage_count)
  end
end