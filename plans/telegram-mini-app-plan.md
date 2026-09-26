# pirosmani-telegram-app: план реализации Telegram Mini App

> Основано на [`ecosystem-architecture.md`](ecosystem-architecture.md) (решение №5),
> реализованном [`pirosmani-telegram-orders`](ecosystem-architecture.md#реализовано-pirosmani-telegram-orders-backend-mvp)
> и текущем [`pirosmani-frontend`](..) (React + Vite + Tailwind).

## Что такое Telegram Mini App

Telegram Mini App — это **обычное веб-приложение** (HTML/JS/CSS), которое
открывается внутри Telegram WebView (не внешний браузер). Telegram встраивает
в WebView JS-SDK (`Telegram.WebApp`), через который приложение получает:

- **`initData`** — подписанные HMAC-SHA256 данные пользователя (user_id,
  first_name, username). Бекенд проверяет подпись ключом бота →
  100% доказательство, что это именно тот Telegram-юзер. **Никаких паролей/OTP.**
- **Тему** (`bg_color`, `text_color`, `hint_color`, `button_color`) — чтобы
  Mini App выглядел нативно в светлой/тёмной теме Telegram.
- **Нативные элементы**: `MainButton` (главная кнопка внизу экрана),
  `BackButton`, `HapticFeedback`, `Popup`, `ScanQrPopup`.
- **Методы**: `openTelegramLink`, `openInvoice` (платежи через Telegram Stars),
  `requestContact` (доступ к номеру телефона).

## Архитектурный принцип

```
Пользователь → Bot (web_app кнопка) → Telegram WebView → https://app.pirosmani.by
                                                              ↓
                                              React Mini App (форк pirosmani-frontend)
                                                              ↓ initData
                                              POST /api/v1/telegram_sessions
                                                              ↓ JWT
                                              Те же api/v1/* (меню, корзина, заказ)
```

**Ключевое решение**: Mini App использует **те же `api/v1` эндпоинты**, что и
`pirosmani-frontend`. Единственное отличие — способ аутентификации: `initData`
вместо телефон+OTP. Бизнес-логика не дублируется.

## Часть 1: Бекенд (`pirosmani-backend`)

### 1.1 Миграция: `telegram_user_id` на `clients`

Файл: `db/migrate/XXXX_add_telegram_fields_to_clients.rb`

```ruby
add_column :clients, :telegram_user_id, :bigint
add_column :clients, :telegram_username, :string
add_column :clients, :telegram_first_name, :string
add_index :clients, :telegram_user_id, unique: true, where: "telegram_user_id IS NOT NULL"
```

Связка Telegram-юзера с существующим `Client`:
- По `telegram_user_id` — уникальный ключ в Telegram (не меняется).
- `Client` может иметь и `phone` (если также логинился через OTP), и
  `telegram_user_id` одновременно.
- `phone` для Telegram-юзеров становится опциональным на уровне валидации
  (см. раздел 1.4) — обязательным он остаётся только для оформления заказа,
  а не для самого факта существования `Client`.

### 1.2 `Auth::TelegramWebAppService` — проверка HMAC

Файл: `app/services/auth/telegram_web_app_service.rb`

Алгоритм проверки `initData` (стандартный для Telegram Mini Apps), **включая
проверку свежести** — без неё `initData` можно перехватить (например, из
логов реверс-прокси) и переиграть повторно от имени чужого пользователя:

```ruby
class Auth::TelegramWebAppService
  MAX_AUTH_AGE = 24.hours

  def self.verify!(init_data_raw)
    # 1. Парсить query-строку initData (приходит как строка вида "key1=val1&key2=val2&...")
    params = URI.decode_www_form(init_data_raw).to_h

    # 2. Извлечь hash (саму подпись)
    received_hash = params.delete("hash")
    return nil unless received_hash

    # 3. Отсортировать оставшиеся пары по ключу, собрать "check string"
    data_check_string = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")

    # 4. Secret key = HMAC-SHA256(bot_token, "WebAppData")
    bot_token = Rails.application.credentials.dig(:telegram, :pirosmani_brest_delivery_bot_token)
    secret_key = OpenSSL::HMAC.digest("SHA256", bot_token, "WebAppData")

    # 5. HMAC-SHA256(secret_key, check_string) == received_hash
    computed_hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)
    return nil unless ActiveSupport::SecurityUtils.secure_compare(computed_hash, received_hash)

    # 6. Защита от replay-атак — Telegram сам рекомендует проверять auth_date.
    # Без этой проверки украденная строка initData (например, из логов) может
    # быть переиграна сколько угодно раз для получения JWT от чужого имени.
    auth_date = Time.at(params["auth_date"].to_i)
    return nil if auth_date < MAX_AUTH_AGE.ago

    # 7. Найти существующего Client по telegram_user_id ИЛИ по совпадающему
    # номеру телефона (если Telegram передал phone через requestContact и
    # человек уже был клиентом через обычный телефон+OTP на pirosmani-frontend
    # — иначе получим ДУБЛИКАТ клиента с раздельной историей заказов/бонусов).
    user_id = params["id"].to_i
    phone = params["phone"]

    client = Client.find_by(telegram_user_id: user_id)
    client ||= Client.find_by(phone: phone) if phone.present?

    if client
      client.update!(
        telegram_user_id: user_id,
        telegram_username: params["username"],
        telegram_first_name: params["first_name"]
      )
    else
      client = Client.create!(
        telegram_user_id: user_id,
        telegram_username: params["username"],
        telegram_first_name: params["first_name"],
        name: params["first_name"] || "Гость",
        phone: phone
      )
    end

    client
  end
end
```

### 1.3 `Api::V1::TelegramSessionsController` — новый роут

Файл: `app/controllers/api/v1/telegram_sessions_controller.rb`

```ruby
module Api
  module V1
    class TelegramSessionsController < BaseController
      def create
        init_data = params[:init_data]
        return render json: { error: "init_data is required" }, status: :bad_request if init_data.blank?

        client = Auth::TelegramWebAppService.verify!(init_data)
        return render json: { error: "Invalid init_data signature" }, status: :unauthorized unless client

        # Если у клиента нет телефона — Mini App запросит его (см. раздел 2.3)
        # и пришёт повторно с phone в initData (через Telegram requestContact)

        session = Auth::IssueClientSession.call(client)
        render json: session_payload(session), status: :created
      end

      private

      def session_payload(session)
        {
          access_token: session[:access_token],
          refresh_token: session[:refresh_token],
          client: {
            id: session[:client].id,
            phone: session[:client].phone,
            name: session[:client].name,
            has_phone: session[:client].phone.present?
          }
        }
      end
    end
  end
end
```

Роут: `config/routes.rb`
```ruby
namespace :api do
  namespace :v1 do
    post :telegram_sessions, to: 'telegram_sessions#create'
  end
end
```

Без `skip_before_action :verify_authenticity_token` — API-контроллер и так
этого не делает (Rails API-only).

### 1.4 Валидация `Client.phone` для Telegram-юзеров

Проблема: `Client.phone` имеет `presence: true`. Telegram-юзер может не
предоставить телефон сразу (Telegram не гарантирует `phone` в `initData` без
явного вызова `requestContact` на фронте).

**Единственное решение** — ослабить валидацию именно для Telegram-клиентов,
без обхода через `save(validate: false)` (обход валидаций — источник багов:
легко пропустить место в коде, которое неявно рассчитывает на присутствие
`phone`):

```ruby
# app/models/client.rb
validates :phone, presence: { message: "Телефон обязателен" },
          uniqueness: { message: "Телефон уже зарегистрирован" },
          unless: :telegram_user_id?
```

Это позволяет Telegram-юзерам существовать без телефона на уровне модели.
Но заказ без телефона всё равно не должен проходить (нужен для
SMS-уведомлений и колбека курьера) — эту проверку делаем явно в
`Api::V1::OrdersController#create` (`return error unless current_client.phone.present?`),
а не полагаемся на валидацию модели. Поэтому Mini App на практике всё равно
запросит телефон через `requestContact` перед оформлением первого заказа
(поток описан в разделе 2.3).

### 1.5 Обновить `BaseController#set_current_client` (опционально)

Если Mini App передаёт JWT (полученный через `telegram_sessions`) в заголовке
`Authorization: Bearer`, то [`BaseController#set_current_client`](../
pirosmani-backend/app/controllers/api/v1/base_controller.rb:8)
работает без изменений — он уже читает JWT и находит `Client.find_by(id:)`.

Единственное: Mini App должен хранить JWT в памяти (не в localStorage —
WebView эфемерен), и при каждом запуске заново вызывать `telegram_sessions`.

## Часть 2: Фронтенд (`pirosmani-telegram-app`)

### 2.1 Скаффолд проекта

Новый репозиторий: `pirosmani-telegram-app`

Структура:
```
pirosmani-telegram-app/
├── index.html
├── package.json          # React 19, Vite 8, Tailwind CSS 4, @telegram-apps/sdk
├── vite.config.ts
├── tsconfig.json
└── src/
    ├── main.tsx           # инициализация Telegram.WebApp, загрузка темы
    ├── App.tsx             # упрощённый роутинг (без BottomNav)
    ├── index.css           # Tailwind + CSS-переменные Telegram темы
    ├── types.ts            # форк из pirosmani-frontend
    ├── services/
    │   └── api.ts          # форк из pirosmani-frontend + telegram_auth
    ├── hooks/
    │   ├── useTelegramAuth.ts  # заменяет useAuth — initData → JWT
    │   ├── useTelegramTheme.ts # Telegram.WebApp.themeParams → CSS-переменные
    │   └── useMainButton.ts    # Telegram.WebApp.MainButton
    └── pages/
        ├── MenuPage.tsx      # форк из pirosmani-frontend (адаптация)
        ├── CartPage.tsx
        ├── CheckoutPage.tsx
        ├── OrdersPage.tsx
        └── ProfilePage.tsx
```

Новые зависимости (`package.json`):
```json
{
  "@telegram-apps/sdk": "^2.0.0",
  "@telegram-apps/sdk-react": "^2.0.0"
}
```

### 2.2 Аутентификация: `useTelegramAuth`

**Отличия от `useAuth`** (который хранит токены в localStorage и использует
телефон+OTP):

```typescript
// useTelegramAuth.ts
import { retrieveLaunchParams } from '@telegram-apps/sdk-react'

export function useTelegramAuth() {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(false)

  const authenticate = useCallback(async () => {
    setLoading(true)
    try {
      const lp = retrieveLaunchParams()  // Telegram WebApp SDK
      const initData = lp.initDataRaw     // сырая строка query-параметров

      const res = await api.telegramLogin(initData)
      // api.telegramLogin → POST /api/v1/telegram_sessions { init_data: initData }
      // В ответе — { access_token, refresh_token, client: {...} }

      api.setTokens(res.access_token, res.refresh_token)

      if (!res.client.has_phone) {
        // Запросить телефон через Telegram requestContact
        // (см. раздел 2.3)
      }

      setUser(res.client)
    } catch (e) {
      // Показать ошибку
    } finally {
      setLoading(false)
    }
  }, [])

  return { user, authenticate, loading }
}
```

Ключевые отличия:
- **Нет localStorage** — токены хранятся только в памяти `ApiService` (state).
  При переоткрытии Mini App — повторный `POST telegram_sessions` с `initData`.
- **Нет OTP** — `initData` уже доказывает личность (подписана Telegram).
- **Авто-логин** — при загрузке Mini App сразу вызываем `authenticate()`.
  Пользователь не видит экран входа.

### 2.3 Запрос телефона: `requestContact`

Поскольку `Client.phone` обязателен для заказа (SMS-уведомления, колбек курьера),
Mini App должен запросить телефон перед первым заказом.

**Поток**:
1. `authenticate()` успешен, но `client.has_phone === false`.
2. Показываем экран запроса телефона: "Для оформления заказа нужен ваш номер
   телефона" + кнопка "Поделиться номером".
3. Кнопка вызывает `Telegram.WebApp.requestContact()` — Telegram показывает
   нативный диалог "Поделиться контактом".
4. После получения телефона — повторный `POST telegram_sessions` (теперь
   `initData` содержит `phone`), бекенд обновляет `Client.phone` (и, если
   номер совпадает с уже существующим `Client`, связывает аккаунты — см.
   раздел 1.2, шаг 7).
5. Далее — обычный JWT, `has_phone === true`.

### 2.4 Адаптация UI под Telegram-тему

```typescript
// useTelegramTheme.ts
import { useSignal } from '@telegram-apps/sdk-react'

export function useTelegramTheme() {
  const themeParams = useSignal('themeParams')

  useEffect(() => {
    if (!themeParams) return
    const root = document.documentElement
    root.style.setProperty('--tg-bg-color', themeParams.bgColor)
    root.style.setProperty('--tg-text-color', themeParams.textColor)
    root.style.setProperty('--tg-hint-color', themeParams.hintColor)
    root.style.setProperty('--tg-link-color', themeParams.linkColor)
    root.style.setProperty('--tg-button-color', themeParams.buttonColor)
    root.style.setProperty('--tg-button-text-color', themeParams.buttonTextColor)
    root.style.setProperty('--tg-secondary-bg-color', themeParams.secondaryBgColor)
  }, [themeParams])
}
```

В `src/index.css` Tailwind-переменные ссылаются на CSS-переменные:
```css
@import 'tailwindcss';

:root {
  --color-bg: var(--tg-bg-color, #FDFBF7);
  --color-text: var(--tg-text-color, #0F0C0C);
  --color-hint: var(--tg-hint-color, #9CA3AF);
  --color-accent: var(--tg-button-color, #E53E3E);
  --color-accent-text: var(--tg-button-text-color, #FFFFFF);
  --color-card: var(--tg-secondary-bg-color, #FFFFFF);
}
```

### 2.5 `MainButton` — главная кнопка Telegram

Вместо кастомной кнопки "Оформить заказ" (как в `pirosmani-frontend`)
используется нативная `MainButton` из Telegram SDK:

```typescript
// useMainButton.ts
import { useSignal, useMainButton as useTgMainButton } from '@telegram-apps/sdk-react'

export function useMainButton(text: string, enabled: boolean, onClick: () => void) {
  const mb = useTgMainButton()

  useEffect(() => {
    if (!mb) return
    mb.setText(text)
    if (enabled) mb.enable(); else mb.disable()
    mb.on('click', onClick)
    return () => mb.off('click', onClick)
  }, [mb, text, enabled, onClick])
}
```

В `CheckoutPage`:
```typescript
useMainButton("Оформить заказ на 45.90 BYN", canOrder, handleOrder)
```

`MainButton` появляется внизу экрана поверх контента — это стандартный
паттерн Telegram Mini Apps. Кнопка всегда видна, не скроллится.

### 2.6 Ключевые отличия вёрстки от `pirosmani-frontend`

| Аспект | pirosmani-frontend | pirosmani-telegram-app |
|---|---|---|
| Навигация | `BottomNav` с 5 вкладками | Telegram `BackButton` + шапка |
| Цвета | Жёстко закодированы (`isDark` проп) | Из `WebApp.themeParams` (адаптивно) |
| Аутентификация | `AuthSheet` — телефон + OTP | Автоматическая через `initData` |
| Корзина | `BottomNav` иконка + `CartPage` | `MainButton` "Корзина (3) на 45.90 BYN" |
| Геолокация | Браузерный `navigator.geolocation` | `WebApp.locationManager` или user location |
| Хранение токенов | `localStorage` | Память (state) — не persist |
| PWA | Да (service worker, install) | Нет (внутри Telegram, не нужен) |

### 2.7 Что переиспользуется из `pirosmani-frontend`

- **Типы** (`types.ts`) — полностью копируем (те же структуры API-ответов).
- **Бизнес-логика** — меню, корзина, чекаут (расчёт цен, доставка) — в бекенде,
  не на фронте. Переиспользуется автоматически через `api/v1`.
- **Компоненты** — `SafeImage`, `VariantPickerSheet` (допы), логика
  `CheckoutPage` (зоны, промо, слоты доставки) — форкаются с минимальными
  изменениями под Telegram-тему и `MainButton`.
- **Стили** — Tailwind утилиты переиспользуются; глобальные цветовые токены
  заменяются на CSS-переменные из `themeParams`.

## Часть 3: Бот в Telegram

### 3.1 Кнопка открытия Mini App

В боте (`@pirosmani_brest_bot` — тот же бот, чей токен используется
для `telegram-orders` и `telegram-app`) добавляем кнопку:

```javascript
// Через Bot API (консоль или скрипт настройки)
fetch(`https://api.telegram.org/bot<TOKEN>/setChatMenuButton`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    menu_button: {
      type: "web_app",
      text: "🍽 Меню",
      web_app: { url: "https://app.pirosmani.by" }
    }
  })
})
```

Или через `@BotFather`: `/setmenubutton` → выбрать бота → `web_app` → текст
"🍽 Меню" → URL.

### 3.2 WebApp URL и хостинг

URL Mini App должен быть:
- **HTTPS** (обязательно для Telegram)
- **Публичный** (не localhost)
- Желательно на основном домене (например `https://app.pirosmani.by` или
  `https://pirosmani.by/mini-app`)

Варианты:
1. Отдельный Vite-билд деплоится на Netlify/Vercel (как текущий frontend).
2. Статические файлы билда отдаются тем же Rails-сервером через
   `public/mini-app/`.
3. Отдельный S3/CloudFront бакет с Cloudflare прокси.

Рекомендация: **Netlify/Vercel** (бесплатный тир, HTTPS из коробки) — тот
же подход, что и для `pirosmani-frontend`.

## Часть 4: Порядок реализации

| Этап | Содержание | Зависимости |
|---|---|---|
| **4.1** | Миграция `clients.telegram_user_id` | — |
| **4.2** | `Auth::TelegramWebAppService` с тестами (WebMock-стабы на HMAC + тест на replay-защиту по `auth_date`) | 4.1 |
| **4.3** | `Api::V1::TelegramSessionsController` + роут | 4.2 |
| **4.4** | Скаффолд `pirosmani-telegram-app` (Vite + `@telegram-apps/sdk`) | — |
| **4.5** | `useTelegramAuth` — аутентификация через `initData` | 4.3, 4.4 |
| **4.6** | `useTelegramTheme` + CSS-переменные Telegram темы | 4.4 |
| **4.7** | `MenuPage` — форк из `pirosmani-frontend`, адаптация под Telegram | 4.5, 4.6 |
| **4.8** | `CartPage` + `MainButton` интеграция | 4.7 |
| **4.9** | `CheckoutPage` — форк чекаута (адреса, зоны, слоты, промо) | 4.8 |
| **4.10** | `OrdersPage` — история заказов | 4.5 |
| **4.11** | Запрос телефона (`requestContact`) — обязательный шаг перед первым заказом, включая связывание с существующим `Client` по номеру | 4.5 |
| **4.12** | Настройка бота (`setChatMenuButton` web_app) + деплой на Netlify | 4.9 |
| **4.13** | Тесты (RSpec для `TelegramSessionsController`, минимум smoke-тестов фронта) | 4.3 |
| **4.14** | Fire-drill тест с реальным ботом и реальным Telegram-аккаунтом | 4.12 |

## Открытые вопросы

1. **Один бот или два?** Сейчас `pirosmani_brest_delivery_bot_token`
   используется для `telegram-orders` (уведомления в канал). Можно
   использовать тот же бот для Mini App (menu_button + web_app), или
   завести отдельный бот для клиентов (`@pirosmani_brest_bot` для Mini App
   vs `@pirosmani_staff_bot` для канала заказов). **Рекомендация: один бот**
   — проще управлять, WebApp URL и канал заказов — разные точки входа в одном
   боте.

2. **Привязка телефона** — обязательный шаг перед первым заказом, как описано
   в 2.3: Mini App запрашивает телефон через `requestContact`. Без телефона
   заказ создать нельзя (SMS-уведомления, колбек курьера).

3. **Связывание аккаунтов** — если человек уже был клиентом через обычный
   `pirosmani-frontend` (телефон+OTP), а потом открывает Mini App, важно НЕ
   создавать второго `Client` с чистой историей заказов/бонусов. Решение
   зафиксировано в разделе 1.2 (шаг 7): после получения телефона через
   `requestContact` ищем существующего `Client` по номеру и привязываем к
   нему `telegram_user_id`, а не создаём новую запись.

4. **Платежи** — `Telegram.WebApp.openInvoice` (Telegram Stars) или обычная
   карта (как сейчас в `pirosmani-frontend` через `CardForm`)? **Пока
   оставляем карту** — Telegram Stars требуют подключения платёжной системы
   Telegram, что добавляет сложность. Mini App может использовать обычную
   HTML-форму карты (как в текущем `CheckoutPage`).

5. **Шеринг кода с `pirosmani-frontend`** — выносить общий код в отдельный
   npm-пакет или форкать? **Пока — форк.** Объём переиспользуемого кода
   недостаточен для отдельного пакета (большая часть бизнес-логики в бекенде);
   UI-компоненты всё равно адаптируются под Telegram WebView. При росте
   дублирования — рефакторинг на общий пакет `@pirosmani/shared`.

## Реализовано: Часть 1 (бекенд)

- Миграция `db/migrate/20260926172055_add_telegram_fields_to_clients.rb` —
  `telegram_user_id` (уникальный частичный индекс), `telegram_username`,
  `telegram_first_name`
- [`Client`](../../pirosmani-backend/app/models/client.rb:1) — валидация
  `phone` теперь `unless: :telegram_user_id?`
- [`Auth::TelegramWebAppService`](../../pirosmani-backend/app/services/auth/telegram_web_app_service.rb:1) —
  HMAC-SHA256 проверка `initData`, защита от replay-атак по `auth_date`
  (24 часа), связывание с существующим `Client` по телефону
- [`Api::V1::TelegramSessionsController`](../../pirosmani-backend/app/controllers/api/v1/telegram_sessions_controller.rb:1) —
  `POST /api/v1/telegram_sessions`, выдаёт ту же JWT-пару, что и обычная сессия
- [`Api::V1::OrdersController#create`](../../pirosmani-backend/app/controllers/api/v1/orders_controller.rb:1) —
  явная проверка `current_client.phone.present?` перед созданием заказа
- Тесты: [`spec/services/auth/telegram_web_app_service_spec.rb`](../../pirosmani-backend/spec/services/auth/telegram_web_app_service_spec.rb:1),
  [`spec/requests/api/v1/telegram_sessions_spec.rb`](../../pirosmani-backend/spec/requests/api/v1/telegram_sessions_spec.rb:1),
  плюс кейсы в `client_spec.rb` и `orders_spec.rb` — 456 examples, 0 failures
- **Не сделано**: Часть 2 (фронтенд `pirosmani-telegram-app`) и Часть 3
  (настройка бота/деплой) — по плану, следующие этапы