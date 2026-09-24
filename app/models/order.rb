class Order < ApplicationRecord
  belongs_to :delivery_zone, optional: true
  belongs_to :client
  belongs_to :client_address, optional: true
  belongs_to :promo_code, optional: true

  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items
  has_many :bonus_transactions, class_name: 'BonusTransaction', dependent: :nullify

  enum status: { pending: "pending", confirmed: "confirmed", cooking: "cooking", delivering: "delivering", done: "done", cancelled: "cancelled" }
  enum order_type: { delivery: "delivery", pickup: "pickup" }, _prefix: true

  validates :address, presence: true, if: -> { order_type_delivery? && client_address.nil? }
  validates :client_address, presence: true, if: -> { order_type_delivery? && address.blank? }

  before_validation :assign_delivery_zone, if: -> { order_type_delivery? && client_address.present? }

  # Начисляем бонусы клиенту когда заказ выполнен
  after_update :award_bonus_points, if: -> { saved_change_to_status? && status == "done" }

  private

  def assign_delivery_zone
    return if delivery_zone.present?
    return if client_address.lat.blank? || client_address.lng.blank?

    zone = DeliveryZone.active.find { |z| z.contains_point?(client_address.lat.to_f, client_address.lng.to_f) }
    self.delivery_zone = zone if zone
  end

  def award_bonus_points
    # Начисляем бонусы только если ещё не начислены (защита от двойного начисления)
    return if bonus_transactions.where(kind: 'earn').exists?

    # Сумма за которую начисляем бонусы = total_price - доставка - бонусная скидка
    # Бонусы начисляются только с суммы блюд, без учёта доставки
    # 1 BYN = 1 бонус, округляем вниз
    paid_by_money = total_price.to_f - delivery_price.to_f - (bonus_points_used * 0.01)
    points_to_earn = paid_by_money.floor

    client.earn_bonuses!(points_to_earn, order: self) if points_to_earn > 0
  end
end
