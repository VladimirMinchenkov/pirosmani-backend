require 'rails_helper'

RSpec.describe OrderItemAddon, type: :model do
  describe 'associations' do
    it { should belong_to(:order_item) }
    it { should belong_to(:addon).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:addon_name) }
    it { should validate_numericality_of(:addon_price).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
  end

  describe 'callbacks' do
    it 'snapshots addon name and price on create' do
      addon = create(:addon, name: 'Bacon', price: 3.00)
      order = create(:order)
      order_item = create(:order_item, order: order)
      order_item_addon = create(:order_item_addon, order_item: order_item, addon: addon)

      expect(order_item_addon.addon_name).to eq('Bacon')
      expect(order_item_addon.addon_price).to eq(3.00)
    end
  end
end