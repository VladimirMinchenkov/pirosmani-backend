FactoryBot.define do
  factory :promotion do
    association :menu_item
    discount_type { "percent" }
    discount_value { 15 }
    active { true }
  end
end