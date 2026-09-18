# Очистка старых данных (в обратном порядке зависимостей)
AdminUser.delete_all
OrderItemAddon.delete_all
OrderItem.delete_all
Order.delete_all
CartItemAddon.delete_all
CartItem.delete_all
Cart.delete_all
MenuItemAddonGroup.delete_all
MenuItemTag.delete_all
MenuItem.delete_all
Addon.delete_all
AddonGroup.delete_all
Tag.delete_all
ProductGroup.delete_all
Category.delete_all
PromoCode.delete_all
DeliveryZone.delete_all
AppSetting.delete_all

# ============================================
# AdminUser
# ============================================
AdminUser.create!(
  email: 'admin@pirosmani.ru',
  password: 'admin123',
  password_confirmation: 'admin123'
)

# ============================================
# AppSettings
# ============================================
AppSetting.find_or_create_by(key: 'delivery_mode') { |s| s.value = 'internal' }
AppSetting.find_or_create_by(key: 'min_order_price') { |s| s.value = '15.00' }

# ============================================
# DeliveryZones
# ============================================
zone = DeliveryZone.create!(
  name: 'Центр города',
  active: true,
  price: 5.00,
  coordinates: [
    [38.0500, 44.5600],
    [38.0700, 44.5600],
    [38.0700, 44.5800],
    [38.0500, 44.5800],
    [38.0500, 44.5600]
  ]
)

# ============================================
# Categories
# ============================================
pizza_cat = Category.create!(name: 'Пицца', icon: '🍕', position: 1)
rolls_cat = Category.create!(name: 'Роллы', icon: '🍣', position: 2)
drinks_cat = Category.create!(name: 'Напитки', icon: '🥤', position: 3)
desserts_cat = Category.create!(name: 'Десерты', icon: '🍰', position: 4)

# ============================================
# ProductGroups
# ============================================
pizza_group = ProductGroup.create!(name: 'Пицца')
rolls_group = ProductGroup.create!(name: 'Роллы')
drinks_group = ProductGroup.create!(name: 'Напитки')
desserts_group = ProductGroup.create!(name: 'Десерты')

# ============================================
# Tags
# ============================================
spicy = Tag.create!(name: 'Острое')
vegan = Tag.create!(name: 'Веганское')
hit = Tag.create!(name: 'Хит')
new_item = Tag.create!(name: 'Новинка')
grill = Tag.create!(name: 'Гриль')

# ============================================
# AddonGroups + Addons
# ============================================
toppings = AddonGroup.create!(name: 'Топпинги', min_selection: 0, max_selection: 5, required: false)
toppings.addons.create!([
  { name: 'Сыр моцарелла', price: 2.00, position: 1 },
  { name: 'Пепперони', price: 2.50, position: 2 },
  { name: 'Грибы', price: 1.50, position: 3 },
  { name: 'Оливки', price: 1.00, position: 4 },
  { name: 'Бекон', price: 3.00, position: 5 }
])

sauces = AddonGroup.create!(name: 'Соусы', min_selection: 0, max_selection: 2, required: false)
sauces.addons.create!([
  { name: 'Чесночный', price: 1.00, position: 1 },
  { name: 'Барбекю', price: 1.00, position: 2 },
  { name: 'Сырный', price: 1.50, position: 3 }
])

drink_size = AddonGroup.create!(name: 'Объём', min_selection: 1, max_selection: 1, required: true)
drink_size.addons.create!([
  { name: '0.3 л', price: 0.00, position: 1 },
  { name: '0.5 л', price: 1.50, position: 2 },
  { name: '1.0 л', price: 3.00, position: 3 }
])

# ============================================
# MenuItems
# ============================================
margherita = MenuItem.create!(
  name: 'Маргарита',
  description: 'Классическая пицца с томатным соусом и сыром моцарелла',
  price: 12.99,
  image_url: 'https://example.com/margherita.jpg',
  available: true,
  category: pizza_cat,
  product_group: pizza_group,
  display_mode: 'simple',
  weight_label: '400 г',
  calories: 850,
  allergens: ['молоко', 'глютен'],
  sku: 'PIZZA-MARG',
  position: 1
)
margherita.tags << [hit]
margherita.addon_groups << [toppings, sauces]

pepperoni = MenuItem.create!(
  name: 'Пепперони',
  description: 'Пицца с острой пепперони и сыром',
  price: 14.99,
  image_url: 'https://example.com/pepperoni.jpg',
  available: true,
  category: pizza_cat,
  product_group: pizza_group,
  display_mode: 'simple',
  weight_label: '420 г',
  calories: 920,
  allergens: ['молоко', 'глютен'],
  sku: 'PIZZA-PEP',
  position: 2
)
pepperoni.tags << [spicy, hit]
pepperoni.addon_groups << [toppings, sauces]

four_cheese = MenuItem.create!(
  name: 'Четыре сыра',
  description: 'Моцарелла, пармезан, горгонзола, рикотта',
  price: 16.99,
  image_url: 'https://example.com/four-cheese.jpg',
  available: true,
  category: pizza_cat,
  product_group: pizza_group,
  display_mode: 'simple',
  weight_label: '400 г',
  calories: 980,
  allergens: ['молоко', 'глютен'],
  sku: 'PIZZA-4CH',
  position: 3
)
four_cheese.tags << [vegan]
four_cheese.addon_groups << [toppings]

philadelphia = MenuItem.create!(
  name: 'Филадельфия',
  description: 'Ролл с лососем, сливочным сыром и авокадо',
  price: 18.99,
  image_url: 'https://example.com/philadelphia.jpg',
  available: true,
  category: rolls_cat,
  product_group: rolls_group,
  display_mode: 'simple',
  weight_label: '250 г',
  calories: 450,
  allergens: ['рыба', 'молоко'],
  sku: 'ROLL-PHIL',
  position: 4
)
philadelphia.tags << [hit, new_item]
philadelphia.addon_groups << [sauces]

caesar_roll = MenuItem.create!(
  name: 'Цезарь ролл',
  description: 'Ролл с курицей, салатом и соусом цезарь',
  price: 14.99,
  image_url: 'https://example.com/caesar-roll.jpg',
  available: true,
  category: rolls_cat,
  product_group: rolls_group,
  display_mode: 'simple',
  weight_label: '240 г',
  calories: 380,
  allergens: ['глютен', 'яйцо'],
  sku: 'ROLL-CAES',
  position: 5
)
caesar_roll.tags << [grill]

cola = MenuItem.create!(
  name: 'Кола',
  description: 'Охлаждённый газированный напиток',
  price: 3.99,
  image_url: 'https://example.com/cola.jpg',
  available: true,
  category: drinks_cat,
  product_group: drinks_group,
  display_mode: 'variant_picker',
  weight_label: nil,
  calories: 140,
  allergens: [],
  sku: 'DRINK-COLA',
  position: 6
)
cola.addon_groups << [drink_size]

water = MenuItem.create!(
  name: 'Вода минеральная',
  description: 'Негазированная минеральная вода',
  price: 1.99,
  image_url: 'https://example.com/water.jpg',
  available: true,
  category: drinks_cat,
  product_group: drinks_group,
  display_mode: 'variant_picker',
  weight_label: nil,
  calories: 0,
  allergens: [],
  sku: 'DRINK-WATER',
  position: 7
)
water.addon_groups << [drink_size]

tiramisu = MenuItem.create!(
  name: 'Тирамису',
  description: 'Классический итальянский десерт',
  price: 7.99,
  image_url: 'https://example.com/tiramisu.jpg',
  available: true,
  category: desserts_cat,
  product_group: desserts_group,
  display_mode: 'simple',
  weight_label: '150 г',
  calories: 320,
  allergens: ['молоко', 'яйцо', 'глютен'],
  sku: 'DES-TIR',
  position: 8
)
tiramisu.tags << [new_item]

# ============================================
# PromoCodes
# ============================================
PromoCode.create!(
  code: 'WELCOME10',
  discount_type: 'fixed',
  discount_value: 10.00,
  min_order_price: 20.00,
  active: true,
  usage_limit: 100,
  usage_count: 0
)

PromoCode.create!(
  code: 'SALE15',
  discount_type: 'percent',
  discount_value: 15.0,
  min_order_price: 30.00,
  active: true,
  usage_limit: 50,
  usage_count: 0
)

PromoCode.create!(
  code: 'FREEDELIVERY',
  discount_type: 'fixed',
  discount_value: 5.00,
  min_order_price: 0.00,
  active: true,
  usage_limit: 200,
  usage_count: 0
)

puts "Seeds loaded: #{Category.count} categories, #{ProductGroup.count} product groups, #{Tag.count} tags"
puts "#{AddonGroup.count} addon groups, #{Addon.count} addons, #{MenuItem.count} menu items"
puts "#{PromoCode.count} promo codes, #{DeliveryZone.count} delivery zones, #{AppSetting.count} app settings"
