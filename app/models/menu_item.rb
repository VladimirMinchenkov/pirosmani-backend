class MenuItem < ApplicationRecord
  has_one_attached :image

  belongs_to :category, optional: true
  belongs_to :menu_item_group, optional: true
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items
  has_many :cart_items
  has_many :menu_item_tags, dependent: :destroy
  has_many :tags, through: :menu_item_tags
  has_many :menu_item_addon_groups, dependent: :destroy
  has_many :addon_groups, through: :menu_item_addon_groups

  validates :name, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :calories, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: true, allow_blank: true
  validates :position_in_category, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_blank: true
  validates :position_in_group, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_blank: true

  before_validation :nilify_blank_positions
  validate :position_fields_mutex

  scope :standalone, -> { where(menu_item_group_id: nil) }
  scope :in_group, -> { where.not(menu_item_group_id: nil) }

  private

  def nilify_blank_positions
    self.position_in_category = nil if position_in_category.blank?
    self.position_in_group = nil if position_in_group.blank?
    self.sku = nil if sku.blank?
    self.image_url = nil if image_url.blank?
  end

  def position_fields_mutex
    if menu_item_group_id.present? && position_in_category.present?
      errors.add(:position_in_category, "must be blank for items in a group")
    end
    if menu_item_group_id.nil? && position_in_group.present?
      errors.add(:position_in_group, "must be blank for standalone items")
    end
  end
end