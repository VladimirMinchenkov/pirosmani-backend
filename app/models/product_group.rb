# app/models/product_group.rb
class ProductGroup < ApplicationRecord
  has_many :menu_items, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: [:create, :update]

  private

  def generate_slug
    return if name.blank?

    self.slug = name.parameterize if slug.blank?
  end
end
