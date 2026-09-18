# app/models/tag.rb
class Tag < ApplicationRecord
  has_many :menu_item_tags, dependent: :destroy
  has_many :menu_items, through: :menu_item_tags

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
end
