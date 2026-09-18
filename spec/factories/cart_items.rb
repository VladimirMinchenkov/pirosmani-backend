# spec/factories/cart_items.rb
FactoryBot.define do
  factory :cart_item do
    cart
    menu_item
    quantity { 1 }
  end
end
