# Архитектура системы акций «Пиросмани»

## Обзор

Система акций состоит из 4 компонентов:

1. **Промокоды** (уже есть) — скидка на весь заказ по коду
2. **Скидки на блюда** (Promotion) — скидка на конкретное блюдо
3. **Комбо-наборы** (Combo) — фиксированный набор блюд по спеццене
4. **Скидка от суммы** (OrderPromotion) — скидка при достижении суммы заказа

---

## 1. Promotion — Скидка на блюдо

### Модель
```ruby
# db/migrate/xxx_create_promotions.rb
create_table :promotions do |t|
  t.references :menu_item, null: false, foreign_key: true
  t.string :discount_type, null: false  # "fixed" или "percent"
  t.decimal :discount_value, null: false # 5.00 BYN или 20%
  t.datetime :starts_at
  t.datetime :ends_at
  t.boolean :active, default: true
  t.timestamps
end
```

### Логика
- Если `discount_type = "fixed"` → цена = `menu_item.price - discount_value`
- Если `discount_type = "percent"` → цена = `menu_item.price * (1 - discount_value/100)`
- Действует в период `starts_at..ends_at`
- На фронтенде: старая цена зачёркнута, новая выделена

### API
- `GET /api/v1/promotions` — активные акции
- `GET /api/v1/menu_items/:id` — включает `promotion` если есть

---

## 2. Combo — Комбо-набор

### Модели
```ruby
# db/migrate/xxx_create_combos.rb
create_table :combos do |t|
  t.string :name, null: false
  t.text :description
  t.decimal :price, null: false  # специальная цена набора
  t.string :image_url
  t.boolean :active, default: true
  t.timestamps
end

# db/migrate/xxx_create_combo_items.rb
create_table :combo_items do |t|
  t.references :combo, null: false, foreign_key: true
  t.references :menu_item, null: false, foreign_key: true
  t.integer :quantity, default: 1
  t.timestamps
end
```

### Логика
- Комбо имеет фиксированную цену (ниже суммы отдельных блюд)
- При добавлении в корзину — добавляются все блюда из набора
- На фронтенде: карточка комбо с перечислением блюд и старой/новой ценой

### API
- `GET /api/v1/combos` — список комбо
- `POST /api/v1/cart/add_combo` — добавить комбо в корзину

---

## 3. OrderPromotion — Скидка от суммы заказа

### Модель
```ruby
# db/migrate/xxx_create_order_promotions.rb
create_table :order_promotions do |t|
  t.decimal :min_amount, null: false  # мин. сумма заказа
  t.string :discount_type, null: false # "fixed" или "percent"
  t.decimal :discount_value, null: false
  t.datetime :starts_at
  t.datetime :ends_at
  t.boolean :active, default: true
  t.timestamps
end
```

### Логика
- Применяется автоматически при достижении `min_amount`
- Может быть только одна активная акция одновременно
- На фронтенде: прогресс-бар «Добавьте ещё X BYN для скидки»

### API
- `GET /api/v1/order_promotions/active` — текущая активная акция
- В расчёте корзины автоматически применяется

---

## 4. PromoCode — Промокод (уже есть)

### Текущая модель
```ruby
# Уже существует
create_table :promo_codes do |t|
  t.string :code, null: false
  t.string :discount_type, null: false  # "fixed" или "percent"
  t.decimal :discount_value, null: false
  t.integer :usage_limit
  t.integer :used_count, default: 0
  t.datetime :valid_until
  t.boolean :active, default: true
end
```

---

## Приоритеты применения скидок

При расчёте заказа скидки применяются в порядке:

1. **Скидки на блюда** (Promotion) — уменьшают цену конкретных блюд
2. **Комбо-наборы** (Combo) — фиксированная цена набора
3. **Скидка от суммы** (OrderPromotion) — применяется к сумме после п.1-2
4. **Промокод** (PromoCode) — применяется к сумме после п.1-3

---

## План реализации

### Этап 1: Бэкенд (миграции + модели + API)
- [ ] Миграции для promotions, combos, combo_items, order_promotions
- [ ] Модели с валидациями
- [ ] Admin-контроллеры (CRUD)
- [ ] API-контроллеры для клиента
- [ ] Сервис расчёта скидок (PromotionCalculator)

### Этап 2: Админка
- [ ] Страница Promotions
- [ ] Страница Combos
- [ ] Страница OrderPromotions
- [ ] Обновить Sidebar (вложить в «Акции»)

### Этап 3: Фронтенд (клиент)
- [ ] Отображение скидок в карточках блюд
- [ ] Отображение комбо-наборов
- [ ] Прогресс-бар скидки от суммы
- [ ] Применение в корзине и чекауте

# Правила непересечения скидок (Discount Stacking Prevention)

## Приоритет скидок (только ОДНА на товар)

Для каждого товара в корзине применяется первая подходящая скидка:

1. **Комбо-набор** → фиксированная цена комбо (промокоды и самовывоз не применяются)
2. **Персональная скидка (Promotion)** → цена со скидкой
3. **Промокод** → применяется только к обычным товарам (без комбо/промо)
4. **Самовывоз** → 15% скидка, только если не применились пункты 1-3
5. **Полная цена** → если ничего не подошло

## Edge Case: фиксированный промокод

Если промокод фиксированный (в рублях) и его сумма больше стоимости «чистых» товаров (без комбо/промо):
- Скидка ограничивается стоимостью доступных товаров
- Не уходит в минус
- Не трогает комбо-наборы

Пример: комбо 2000₽ + хинкали 250₽, промокод на 300₽ → скидка = 250₽ (хинкали до 0₽, комбо не тронуто)

## Расчёт итогов

- `items_total` — база для всех скидок (только стоимость блюд)
- `delivery_total` — добавляется после всех скидок, не участвует в расчёте
- `grand_total = items_total_after_discounts + delivery_total`

## Изменения в PromotionCalculator

1. Добавить `delivery_type` ('delivery' | 'pickup')
2. Добавить флаг `combo_item` для товаров из комбо
3. `apply_item_promotions` — пропускать combo_item
4. `apply_promo_code` — только к товарам без комбо/промо, с ограничением по сумме
5. `apply_pickup_discount` — только к товарам без комбо/промо/промокода
6. Доставка исключена из базы расчёта скидок