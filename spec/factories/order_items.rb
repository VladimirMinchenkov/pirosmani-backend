FactoryBot.define do
  factory :order_item do
    order { nil }
    menu_item { nil }
    quantity { 1 }
    price { "9.99" }
  end
end
