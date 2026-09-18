FactoryBot.define do
  factory :order_item_addon do
    order_item
    addon
    addon_name { addon.name }
    addon_price { addon.price }
    quantity { 1 }
  end
end