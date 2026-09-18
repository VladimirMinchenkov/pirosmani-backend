# Admin SPA — Архитектура

## Обзор

Отдельное React SPA-приложение для администрирования pirosmani-backend.  
Располагается рядом с бэкендом: `/Users/vladimir/projects/pirosmani-backend/` и `/Users/vladimir/projects/pirosmani-admin/`.

## Стек

| Слой | Технология |
|------|-----------|
| Бандлер | Vite |
| UI-фреймворк | React 18+ |
| Роутинг | React Router v6 |
| Серверное состояние | TanStack Query (React Query) v5 |
| Стили | TailwindCSS |
| Формы | React Hook Form + Zod (валидация) |
| HTTP-клиент | axios (interceptor для Bearer-токена) |
| Уведомления | react-hot-toast |
| Иконки | lucide-react |
| Таблицы | @tanstack/react-table |

## Структура проекта

```
pirosmani-admin/
├── index.html
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
├── package.json
├── src/
│   ├── main.tsx                    # entry point
│   ├── App.tsx                     # router + providers
│   ├── api/
│   │   ├── client.ts               # axios instance + interceptor
│   │   ├── auth.ts                 # login()
│   │   ├── menuItems.ts            # CRUD menu items
│   │   ├── categories.ts           # CRUD categories
│   │   ├── tags.ts                 # CRUD tags
│   │   ├── productGroups.ts        # CRUD product groups
│   │   ├── addonGroups.ts          # CRUD addon groups + addons
│   │   ├── orders.ts               # list/show/update status
│   │   ├── promoCodes.ts           # CRUD promo codes
│   │   ├── appSettings.ts          # list/update settings
│   │   └── deliveryZones.ts        # CRUD delivery zones
│   ├── hooks/
│   │   ├── useAuth.ts              # login/logout/check
│   │   ├── useMenuItems.ts         # TanStack Query hooks
│   │   ├── useCategories.ts
│   │   ├── useTags.ts
│   │   ├── useProductGroups.ts
│   │   ├── useAddonGroups.ts
│   │   ├── useOrders.ts
│   │   ├── usePromoCodes.ts
│   │   └── useAppSettings.ts
│   ├── components/
│   │   ├── ui/                     # переиспользуемые UI-компоненты
│   │   │   ├── Button.tsx
│   │   │   ├── Input.tsx
│   │   │   ├── Modal.tsx
│   │   │   ├── Select.tsx
│   │   │   ├── MultiSelect.tsx
│   │   │   ├── Table.tsx
│   │   │   ├── Badge.tsx
│   │   │   ├── Card.tsx
│   │   │   ├── Spinner.tsx
│   │   │   └── ConfirmDialog.tsx
│   │   ├── layout/
│   │   │   ├── AdminLayout.tsx      # sidebar + header + outlet
│   │   │   ├── Sidebar.tsx
│   │   │   └── Header.tsx
│   │   └── forms/
│   │       ├── MenuItemForm.tsx     # create/edit menu item
│   │       ├── CategoryForm.tsx
│   │       ├── TagForm.tsx
│   │       ├── ProductGroupForm.tsx
│   │       ├── AddonGroupForm.tsx
│   │       ├── AddonForm.tsx
│   │       ├── PromoCodeForm.tsx
│   │       └── OrderStatusSelect.tsx
│   ├── pages/
│   │   ├── LoginPage.tsx
│   │   ├── DashboardPage.tsx        # статистика (кол-во заказов, выручка)
│   │   ├── MenuItemsPage.tsx
│   │   ├── CategoriesPage.tsx
│   │   ├── TagsPage.tsx
│   │   ├── ProductGroupsPage.tsx
│   │   ├── AddonGroupsPage.tsx
│   │   ├── OrdersPage.tsx
│   │   ├── OrderDetailPage.tsx
│   │   ├── PromoCodesPage.tsx
│   │   ├── AppSettingsPage.tsx
│   │   └── DeliveryZonesPage.tsx
│   ├── types/
│   │   └── index.ts                 # TypeScript-типы для всех сущностей
│   ├── lib/
│   │   └── utils.ts                 # cn(), formatPrice(), etc.
│   └── stores/
│       └── authStore.ts             # Zustand: token, admin info
```

## Аутентификация

```
POST /admin/v1/login  →  { token: "abc...", admin: { id, email } }
```

- Токен хранится в `localStorage`
- axios interceptor добавляет `Authorization: Bearer <token>` ко всем запросам
- При 401 — редирект на `/login`
- Zustand-стор для хранения `token` + `admin`

## Роутинг (React Router)

| Путь | Страница | Доступ |
|------|----------|--------|
| `/login` | LoginPage | без авторизации |
| `/` | DashboardPage | авторизован |
| `/menu-items` | MenuItemsPage | авторизован |
| `/menu-items/new` | MenuItemsPage (форма) | авторизован |
| `/menu-items/:id/edit` | MenuItemsPage (форма) | авторизован |
| `/categories` | CategoriesPage | авторизован |
| `/tags` | TagsPage | авторизован |
| `/product-groups` | ProductGroupsPage | авторизован |
| `/addon-groups` | AddonGroupsPage | авторизован |
| `/orders` | OrdersPage | авторизован |
| `/orders/:id` | OrderDetailPage | авторизован |
| `/promo-codes` | PromoCodesPage | авторизован |
| `/settings` | AppSettingsPage | авторизован |
| `/delivery-zones` | DeliveryZonesPage | авторизован |

## API-эндпоинты (уже готовы)

Все эндпоинты префиксованы `/admin/v1/`:

| Метод | Путь | Назначение |
|-------|------|-----------|
| POST | `/login` | Авторизация |
| GET/POST | `/menu_items` | Список / создание |
| GET/PATCH/DELETE | `/menu_items/:id` | Детали / обновление / удаление |
| GET/POST | `/categories` | Список / создание |
| GET/PATCH/DELETE | `/categories/:id` | Детали / обновление / удаление |
| GET/POST | `/tags` | Список / создание |
| GET/PATCH/DELETE | `/tags/:id` | Детали / обновление / удаление |
| GET/POST | `/product_groups` | Список / создание |
| GET/PATCH/DELETE | `/product_groups/:id` | Детали / обновление / удаление |
| GET/POST | `/addon_groups` | Список / создание |
| GET/PATCH/DELETE | `/addon_groups/:id` | Детали / обновление / удаление |
| POST/PATCH/DELETE | `/addon_groups/:id/addons` | CRUD аддонов внутри группы |
| GET | `/orders` | Список заказов |
| GET/PATCH | `/orders/:id` | Детали / смена статуса |
| GET/POST | `/promo_codes` | Список / создание |
| GET/PATCH/DELETE | `/promo_codes/:id` | Детали / обновление / удаление |
| GET | `/app_settings` | Список настроек |
| PATCH | `/app_settings/:id` | Обновление значения |
| GET/POST | `/delivery_zones` | Список / создание |
| GET/PATCH/DELETE | `/delivery_zones/:id` | Детали / обновление / удаление |

## Поток данных (TanStack Query)

```
Page → useQuery(key, apiFn) → axios → /admin/v1/...
     → useMutation(key, apiFn) → invalidateQueries → refetch
```

Пример для menu items:
```ts
// hooks/useMenuItems.ts
export function useMenuItems() {
  return useQuery({
    queryKey: ['menuItems'],
    queryFn: () => api.get('/admin/v1/menu_items').then(r => r.data)
  })
}

export function useCreateMenuItem() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data) => api.post('/admin/v1/menu_items', data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['menuItems'] })
  })
}
```

## Страницы — детали

### DashboardPage
- Карточки: всего заказов (сегодня), выручка (сегодня), активных позиций меню
- Можно сделать позже, начать с заглушки

### MenuItemsPage
- Таблица: фото, название, категория, цена, available (toggle), теги
- Кнопка «Добавить» → модальное окно с MenuItemForm
- Клик по строке → модальное окно редактирования
- MenuItemForm:
  - Поля: name, description, price, image_url, weight_label, calories, sku, position
  - Select: category (из useCategories)
  - Select: product_group (из useProductGroups)
  - MultiSelect: tags (из useTags)
  - MultiSelect: addon_groups (из useAddonGroups)
  - Checkbox: available
  - Select: display_mode (simple / variant_picker)
  - Allergens: чипсы/теги (молоко, глютен, рыба...)

### CategoriesPage / TagsPage / ProductGroupsPage
- Простая таблица + модалка с формой (1-2 поля)

### AddonGroupsPage
- Таблица групп аддонов
- Раскрывающийся список аддонов внутри группы
- Добавление/редактирование/удаление аддонов внутри группы

### OrdersPage
- Таблица: ID, клиент, статус (Badge), сумма, тип, дата
- Фильтр по статусу
- Клик → OrderDetailPage: состав заказа, addons, адрес, возможность сменить статус

### PromoCodesPage
- Таблица: код, тип скидки, значение, лимит/использовано, active
- Форма: все поля из PromoCodeSerializer

### AppSettingsPage
- Список key-value с возможностью редактирования значения (inline или модалка)

### DeliveryZonesPage
- Таблица: название, цена, active
- Форма: название, цена, координаты (JSON-поле — textarea с валидацией)

## Порядок реализации

1. Инициализация Vite + React + Tailwind + зависимости
2. [`api/client.ts`](src/api/client.ts) — axios instance с interceptor
3. [`stores/authStore.ts`](src/stores/authStore.ts) — Zustand
4. [`pages/LoginPage.tsx`](src/pages/LoginPage.tsx) — форма логина
5. [`components/layout/`](src/components/layout/) — AdminLayout, Sidebar, Header
6. [`App.tsx`](src/App.tsx) — роутер с ProtectedRoute
7. Поочерёдно: Categories → Tags → ProductGroups → AddonGroups (самые простые)
8. MenuItems (самая сложная форма)
9. Orders
10. PromoCodes
11. AppSettings
12. DeliveryZones
13. Dashboard (статистика)

## Конфигурация Vite

```ts
// vite.config.ts
export default defineConfig({
  plugins: [react()],
  server: {
    port: 3001,
    proxy: {
      '/admin': 'http://localhost:3000'  // прокси к Rails API
    }
  }
})
```

## Переменные окружения

```
VITE_API_BASE_URL=http://localhost:3000