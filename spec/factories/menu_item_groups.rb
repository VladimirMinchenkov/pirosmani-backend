FactoryBot.define do
  factory :menu_item_group do
    sequence(:name) { |n| "Menu Item Group #{n}" }
    sequence(:slug) { |n| "menu-item-group-#{n}" }
    category
    position_in_category { 0 }
    available { true }
  end
end