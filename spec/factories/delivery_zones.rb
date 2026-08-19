FactoryBot.define do
  coordinates = [
    [38.0500, 44.5600],
    [38.0700, 44.5600],
    [38.0700, 44.5800],
    [38.0500, 44.5800],
    [38.0500, 44.5600]  # замыкаем полигон
  ]
  
  factory :delivery_zone do
    name { "MyString" }
    coordinates { coordinates }
    active { false }
  end
end
