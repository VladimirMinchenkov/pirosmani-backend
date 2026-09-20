class Category < ApplicationRecord
  has_one_attached :image

  has_many :menu_items, dependent: :nullify
  has_many :menu_item_groups, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end