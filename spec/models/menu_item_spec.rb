require 'rails_helper'

RSpec.describe MenuItem, type: :model do
  describe 'associations' do
    it { should belong_to(:category).optional }
    it { should belong_to(:menu_item_group).optional }
    it { should have_many(:order_items) }
    it { should have_many(:orders).through(:order_items) }
    it { should have_many(:cart_items) }
    it { should have_many(:menu_item_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:menu_item_tags) }
    it { should have_many(:menu_item_addon_groups).dependent(:destroy) }
    it { should have_many(:addon_groups).through(:menu_item_addon_groups) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
    it { should validate_numericality_of(:calories).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe 'factory' do
    it 'creates a valid menu item' do
      item = build(:menu_item)
      expect(item).to be_valid
    end

    it 'creates menu item with tags' do
      item = create(:menu_item, :with_tags, tags_count: 3)
      expect(item.tags.count).to eq(3)
    end

    it 'creates menu item with addon groups' do
      item = create(:menu_item, :with_addon_groups, addon_groups_count: 2)
      expect(item.addon_groups.count).to eq(2)
      expect(item.addon_groups.first.addons).not_to be_empty
    end
  end
end
