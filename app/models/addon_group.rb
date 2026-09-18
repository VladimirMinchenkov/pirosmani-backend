# app/models/addon_group.rb
class AddonGroup < ApplicationRecord
  has_many :addons, -> { order(:position) }, dependent: :destroy
  has_many :menu_item_addon_groups, dependent: :destroy
  has_many :menu_items, through: :menu_item_addon_groups

  validates :name, presence: true, uniqueness: true
  validates :min_selection, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_selection, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :max_selection_not_less_than_min

  private

  def max_selection_not_less_than_min
    return if max_selection.nil?

    errors.add(:max_selection, "must be greater than or equal to min_selection") if max_selection < min_selection
  end
end
