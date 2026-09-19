FactoryBot.define do
  factory :menu_item do
    sequence(:name) { |n| "Menu Item #{n}" }
    description { "Delicious food" }
    price { 9.99 }
    image_url { "https://example.com/image.jpg" }
    available { true }
    weight_label { "250g" }
    calories { 350 }
    allergens { [] }
    sequence(:sku) { |n| "SKU-#{n}" }
    sequence(:position) { |n| n }
    category

    trait :unavailable do
      available { false }
    end

    trait :variant_picker do
    end

    trait :with_tags do
      transient do
        tags_count { 2 }
      end

      after(:create) do |item, evaluator|
        item.tags << create_list(:tag, evaluator.tags_count)
      end
    end

    trait :with_addon_groups do
      transient do
        addon_groups_count { 2 }
      end

      after(:create) do |item, evaluator|
        item.addon_groups << create_list(:addon_group, evaluator.addon_groups_count, :with_addons)
      end
    end
  end
end
