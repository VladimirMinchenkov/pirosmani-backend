# План: MenuItemGroup + смешанный порядок в категориях

## Анализ текущего состояния

Уже есть:
- `ProductGroup` (id, name, slug) — нужно переименовать в `MenuItemGroup`
- `MenuItem` имеет `product_group_id` — переименовать в `menu_item_group_id`
- `MenuItem` имеет `position` — используется для сортировки ВСЕХ блюд
- `Category` имеет `has_many :menu_items`

Нужно добавить:
- `MenuItemGroup`: `position_in_category`, `min_total_quantity`, `description`, `image_url`, `available`
- `MenuItem`: `position_in_category` (для самостоятельных), `position_in_group` (для блюд в группе)
- Смешанный порядок: самостоятельные MenuItem + MenuItemGroup в одном списке

## План реализации

### Фаза 1: Миграции и модели (бэкенд)

1. **Миграция: переименовать product_groups → menu_item_groups**
   - `rename_table :product_groups, :menu_item_groups`
   - `rename_column :menu_items, :product_group_id, :menu_item_group_id`

2. **Миграция: добавить поля в menu_item_groups**
   - `position_in_category :integer, default: 0, null: false`
   - `min_total_quantity :integer`
   - `description :text`
   - `image_url :string`
   - `available :boolean, default: true`

3. **Миграция: добавить поля в menu_items**
   - `position_in_category :integer` (для самостоятельных блюд)
   - `position_in_group :integer` (для блюд в группе)
   - Уникальные индексы

4. **Обновить модели:**
   - `MenuItemGroup` (бывший ProductGroup)
   - `MenuItem` — валидации: если в группе → position_in_group, иначе position_in_category
   - `Category` — `has_many :menu_item_groups`

### Фаза 2: API для клиента

5. **Новый endpoint:** `GET /api/v1/categories/:id/menu`
   - Возвращает единый список: `{ category, items: [...] }`
   - `items` содержит `{ type: "menu_item" | "menu_item_group", ... }`
   - Сортировка по `position_in_category`
   - Внутри группы — `items` отсортированы по `position_in_group`
   - Без N+1 (includes)

### Фаза 3: Админские endpoints

6. **CRUD для MenuItemGroup:**
   - `POST /admin/v1/categories/:id/menu_item_groups`
   - `PATCH /admin/v1/menu_item_groups/:id`
   - `DELETE /admin/v1/menu_item_groups/:id`

7. **Reorder категории:**
   - `PATCH /admin/v1/categories/:id/content/reorder`
   - Принимает `{ items: [{ type, id, position_in_category }] }`

8. **Reorder группы:**
   - `PATCH /admin/v1/menu_item_groups/:id/items/reorder`
   - Принимает `{ items: [{ id, position_in_group }] }`

9. **Добавление блюда в группу:**
   - `POST /admin/v1/menu_item_groups/:id/menu_items`

### Фаза 4: Админка (React)

10. **Обновить страницы:**
    - Переименовать ProductGroups → MenuItemGroups
    - Добавить поле `min_total_quantity`, `description`, `image_url`
    - В CategoriesPage — показывать смешанный список с drag-and-drop

### Фаза 5: Фронтенд (клиентский)

11. **Обновить MenuPage:**
    - Загружать `GET /api/v1/categories/:id/menu`
    - Отображать MenuItemGroup как карточку-группу
    - При клике на группу → VariantPickerSheet с вариантами из группы

12. **Обновить VariantPickerSheet:**
    - Принимать `group: MenuItemGroup` и `variants: MenuItem[]`
    - Показывать варианты + addon_groups (соусы)

### Фаза 6: Тесты

13. Model specs, request specs для всех новых endpoints

## Оценка

Задача выполнима. Основной объём — миграции, модели, API (фазы 1-3). Админка и фронтенд (фазы 4-5) — следующий шаг.

**Порядок:** начинаю с Фазы 1 (миграции + модели), затем Фаза 2 (клиентский API), затем Фаза 3 (админские endpoints).