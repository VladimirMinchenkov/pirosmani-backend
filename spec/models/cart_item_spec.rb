# spec/models/cart_item_spec.rb
require 'rails_helper'

RSpec.describe CartItem, type: :model do
  it { should belong_to(:cart) }
  it { should belong_to(:menu_item) }
  it { should validate_numericality_of(:quantity).is_greater_than(0) }

  it 'не позволяет дублировать menu_item в одной корзине' do
    cart = create(:cart)
    menu_item = create(:menu_item)
    create(:cart_item, cart: cart, menu_item: menu_item)

    duplicate = build(:cart_item, cart: cart, menu_item: menu_item)
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
