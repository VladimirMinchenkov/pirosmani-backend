FactoryBot.define do
  factory :addon do
    addon_group
    sequence(:name) { |n| "Addon #{n}" }
    price { 1.50 }
    sequence(:position) { |n| n }
  end
end