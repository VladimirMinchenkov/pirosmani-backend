# app/models/bonus_transaction.rb
class BonusTransaction < ApplicationRecord
  KINDS = %w[earn spend].freeze

  belongs_to :client
  belongs_to :order, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :amount, numericality: { greater_than: 0, only_integer: true }
  validates :description, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :earnings, -> { where(kind: 'earn') }
  scope :spendings, -> { where(kind: 'spend') }
end
