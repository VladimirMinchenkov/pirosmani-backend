FactoryBot.define do
  factory :cart_item_addon do
    cart_item
    addon
    addon_name { addon.name }
    addon_price { addon.price }
    quantity { 1 }
  end
end