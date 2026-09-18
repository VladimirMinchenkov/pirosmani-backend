FactoryBot.define do
  factory :product_group do
    sequence(:name) { |n| "Product Group #{n}" }
    sequence(:slug) { |n| "product-group-#{n}" }
  end
end