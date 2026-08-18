class Cart < ApplicationRecord
  enum status: { active: 0, merged: 1, archived: 2 } 

  belongs_to :client, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items
  

  validate :client_or_session_present

  private

  def client_or_session_present
    if client_id.blank? && session_id.blank?
      errors.add(:base, "Должен быть указан либо client_id, либо session_id")
    end

    if client_id.present? && session_id.present?
      errors.add(:base, "Нельзя одновременно указывать и client_id, и session_id")
    end
  end
end
