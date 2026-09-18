FactoryBot.define do
  factory :order_item do
    order
    menu_item
    quantity { 1 }
    price { menu_item.price }

    trait :with_addons do
      transient do
        addons_count { 2 }
      end

      after(:create) do |item, evaluator|
        create_list(:order_item_addon, evaluator.addons_count, order_item: item)
      end
    end
  end
end
