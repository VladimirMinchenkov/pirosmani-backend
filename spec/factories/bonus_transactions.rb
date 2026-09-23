FactoryBot.define do
  factory :bonus_transaction do
    client
    order
    kind { "earn" }
    amount { 10 }
    description { "Начисление за заказ ##{order&.id || 1}" }

    trait :earn do
      kind { "earn" }
    end

    trait :spend do
      kind { "spend" }
      description { "Оплата бонусами заказа ##{order&.id || 1}" }
    end
  end
end