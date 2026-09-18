class Order < ApplicationRecord
  belongs_to :delivery_zone, optional: true
  belongs_to :client
  belongs_to :client_address, optional: true

  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  enum status: { pending: "pending", confirmed: "confirmed", cooking: "cooking", delivering: "delivering", done: "done", cancelled: "cancelled" }
  enum order_type: { delivery: "delivery", pickup: "pickup" }, _prefix: true

  validates :address, presence: true, if: -> { order_type_delivery? && client_address.nil? }
  validates :client_address, presence: true, if: -> { order_type_delivery? && address.blank? }

  before_validation :assign_delivery_zone, if: -> { order_type_delivery? && client_address.present? }

  private

  def assign_delivery_zone
    return if delivery_zone.present?
    return if client_address.lat.blank? || client_address.lng.blank?

    zone = DeliveryZone.active.find { |z| z.contains_point?(client_address.lat.to_f, client_address.lng.to_f) }
    self.delivery_zone = zone if zone
  end
end
