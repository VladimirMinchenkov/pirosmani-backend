FactoryBot.define do
  factory :combo do
    name { "Комбо-набор" }
    price { 89.00 }
    active { true }
  end

  factory :combo_item do
    association :combo
    association :menu_item
    quantity { 1 }
  end
end