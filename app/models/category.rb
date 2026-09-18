# app/models/category.rb
class Category < ApplicationRecord
  has_many :menu_items, dependent: :nullify

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end