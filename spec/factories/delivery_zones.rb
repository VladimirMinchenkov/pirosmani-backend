FactoryBot.define do
  coordinates = [
    [38.0500, 44.5600],
    [38.0700, 44.5600],
    [38.0700, 44.5800],
    [38.0500, 44.5800],
    [38.0500, 44.5600]  # замыкаем полигон
  ]

  factory :delivery_zone do
    name { "Центральный район" }
    coordinates { coordinates }
    price { 10.0 }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :without_price do
      price { nil }
    end
  end
end
