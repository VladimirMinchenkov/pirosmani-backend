require 'rails_helper'

RSpec.describe AddonGroup, type: :model do
  describe 'associations' do
    it { should have_many(:addons).dependent(:destroy) }
    it { should have_many(:menu_item_addon_groups).dependent(:destroy) }
    it { should have_many(:menu_items).through(:menu_item_addon_groups) }
  end

  describe 'validations' do
    subject { build(:addon_group) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_numericality_of(:min_selection).only_integer.is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:max_selection).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe 'custom validations' do
    it 'is invalid when max_selection is less than min_selection' do
      group = build(:addon_group, min_selection: 3, max_selection: 1)
      expect(group).not_to be_valid
      expect(group.errors[:max_selection]).to include("must be greater than or equal to min_selection")
    end

    it 'is valid when max_selection is nil (unlimited)' do
      group = build(:addon_group, min_selection: 1, max_selection: nil)
      expect(group).to be_valid
    end

    it 'is valid when max_selection equals min_selection' do
      group = build(:addon_group, min_selection: 2, max_selection: 2)
      expect(group).to be_valid
    end
  end
end