# app/models/product_group.rb
class ProductGroup < ApplicationRecord
  has_many :menu_items, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
end
