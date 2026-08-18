# spec/models/cart_item_spec.rb
require 'rails_helper'

RSpec.describe CartItem, type: :model do
  it { should belong_to(:cart) }
  it { should belong_to(:product) }
  it { should validate_numericality_of(:quantity).is_greater_than(0) }

  it 'не позволяет дублировать product в одной корзине' do
    cart = create(:cart)
    product = create(:product)
    create(:cart_item, cart: cart, product: product)

    duplicate = build(:cart_item, cart: cart, product: product)
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end