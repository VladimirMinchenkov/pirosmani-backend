# app/models/client_address.rb
class ClientAddress < ApplicationRecord
  belongs_to :client
  has_many :orders, dependent: :nullify

  validates :street, presence: true
  validates :lat, numericality: true, allow_nil: true
  validates :lng, numericality: true, allow_nil: true

  def full_address
    parts = [street]
    parts << "подъезд #{entrance}" if entrance.present?
    parts << "кв. #{apt}" if apt.present?
    parts << "этаж #{floor}" if floor.present?
    parts.join(", ")
  end
end
