FactoryBot.define do
  factory :menu_item_group do
    sequence(:name) { |n| "Product Group #{n}" }
    sequence(:slug) { |n| "product-group-#{n}" }
  end
end