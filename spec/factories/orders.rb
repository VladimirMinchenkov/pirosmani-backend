FactoryBot.define do
  factory :order do
    client
    status { "pending" }
    order_type { "delivery" }
    address { "ул. Ленина, д. 1, кв. 5" }
    total_price { 29.99 }
    delivery_price { 5.00 }

    trait :pickup do
      order_type { "pickup" }
      address { nil }
    end

    trait :with_items do
      transient do
        items_count { 2 }
      end

      after(:create) do |order, evaluator|
        create_list(:order_item, evaluator.items_count, order: order)
      end
    end
  end
end
