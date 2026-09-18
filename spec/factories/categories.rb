FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    icon { "🍕" }
    sequence(:position) { |n| n }
  end
end