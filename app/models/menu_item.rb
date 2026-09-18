class MenuItem < ApplicationRecord
  DISPLAY_MODES = %w[simple variant_picker].freeze

  belongs_to :category, optional: true
  belongs_to :product_group, optional: true
  has_many :order_items
  has_many :orders, through: :order_items
  has_many :cart_items
  has_many :menu_item_tags, dependent: :destroy
  has_many :tags, through: :menu_item_tags
  has_many :menu_item_addon_groups, dependent: :destroy
  has_many :addon_groups, through: :menu_item_addon_groups

  validates :name, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :display_mode, inclusion: { in: DISPLAY_MODES }
  validates :calories, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: true, allow_nil: true
end