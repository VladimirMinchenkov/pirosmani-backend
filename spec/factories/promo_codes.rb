FactoryBot.define do
  factory :promo_code do
    sequence(:code) { |n| "PROMO#{n}" }
    discount_type { "fixed" }
    discount_value { 10.00 }
    min_order_price { 20.00 }
    active { true }
    usage_limit { 100 }
    usage_count { 0 }

    trait :percent do
      discount_type { "percent" }
      discount_value { 15.0 }
    end

    trait :inactive do
      active { false }
    end

    trait :expired do
      active_until { 1.day.ago }
    end

    trait :depleted do
      usage_limit { 5 }
      usage_count { 5 }
    end
  end
end