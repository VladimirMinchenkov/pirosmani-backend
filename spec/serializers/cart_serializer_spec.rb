require 'rails_helper'

RSpec.describe CartSerializer do
  let(:cart) { create(:cart, :for_session) }
  let(:menu_item) { create(:menu_item, name: 'Test Pizza', price: 12.99) }
  let(:addon) { create(:addon, name: 'Cheese', price: 2.00) }
  let(:cart_item) { create(:cart_item, cart: cart, menu_item: menu_item, quantity: 2) }

  before do
    create(:cart_item_addon, cart_item: cart_item, addon: addon)
  end

  subject(:serialized) { described_class.new(cart.reload).as_json }

  it 'includes cart id and session_id' do
    expect(serialized[:id]).to eq(cart.id)
    expect(serialized[:session_id]).to eq(cart.session_id)
  end

  it 'includes cart items with menu item data' do
    expect(serialized[:cart_items].size).to eq(1)
    expect(serialized[:cart_items].first[:name]).to eq('Test Pizza')
    expect(serialized[:cart_items].first[:price]).to eq(12.99)
    expect(serialized[:cart_items].first[:quantity]).to eq(2)
  end

  it 'includes addons for each cart item' do
    addons = serialized[:cart_items].first[:addons]
    expect(addons.size).to eq(1)
    expect(addons.first[:name]).to eq('Cheese')
    expect(addons.first[:price]).to eq(2.00)
    expect(addons.first[:quantity]).to eq(1)
  end

  it 'serializes empty cart' do
    empty_cart = create(:cart, :for_session)
    result = described_class.new(empty_cart).as_json

    expect(result[:cart_items]).to be_empty
  end
end