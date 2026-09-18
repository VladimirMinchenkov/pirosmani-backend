require 'rails_helper'

RSpec.describe CartItemAddon, type: :model do
  describe 'associations' do
    it { should belong_to(:cart_item) }
    it { should belong_to(:addon).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:addon_name) }
    it { should validate_numericality_of(:addon_price).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
  end

  describe 'callbacks' do
    it 'snapshots addon name and price on create' do
      addon = create(:addon, name: 'Extra Cheese', price: 2.50)
      cart_item = create(:cart_item)
      cart_item_addon = create(:cart_item_addon, cart_item: cart_item, addon: addon)

      expect(cart_item_addon.addon_name).to eq('Extra Cheese')
      expect(cart_item_addon.addon_price).to eq(2.50)
    end

    it 'does not fail when addon is nil' do
      cart_item = create(:cart_item)
      cart_item_addon = build(:cart_item_addon, cart_item: cart_item, addon: nil,
                                addon_name: 'Manual Addon', addon_price: 1.00)

      expect(cart_item_addon).to be_valid
    end
  end
end