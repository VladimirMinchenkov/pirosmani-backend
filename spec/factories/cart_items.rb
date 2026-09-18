# spec/factories/cart_items.rb
FactoryBot.define do
  factory :cart_item do
    cart
    menu_item
    quantity { 1 }
    price { menu_item.price }

    trait :with_addons do
      transient do
        addons_count { 2 }
      end

      after(:create) do |item, evaluator|
        create_list(:cart_item_addon, evaluator.addons_count, cart_item: item)
      end
    end
  end
end
