FactoryBot.define do
  factory :order_promotion do
    min_amount { 50 }
    discount_type { "percent" }
    discount_value { 10 }
    active { true }
  end
end