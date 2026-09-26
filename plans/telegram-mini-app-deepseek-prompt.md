# Промпт и порядок действий для DeepSeek: Telegram Mini App (Часть 2 + Часть 3)

> Контекст: полный план — [`plans/telegram-mini-app-plan.md`](telegram-mini-app-plan.md).
> **Часть 1 (бекенд) уже полностью реализована и протестирована** в `pirosmani-backend`
> (миграция `clients.telegram_user_id`, `Auth::TelegramWebAppService`,
> `Api::V1::TelegramSessionsController`, роут `POST /api/v1/telegram_sessions`).
> DeepSeek должен реализовать **только Часть 2 (фронтенд) и Часть 3 (бот/деплой)**,
> backend-репозиторий не трогать.

---

## Промпт для DeepSeek (копировать целиком в начало задачи)

```
Ты реализуешь фронтенд Telegram Mini App для кафе Pirosmani.

КОНТЕКСТ:
- Полный архитектурный план лежит в pirosmani-backend/plans/telegram-mini-app-plan.md.
  Прочитай его целиком перед началом — там есть готовые code-сниппеты для каждого файла.
- Backend уже готов: POST /api/v1/telegram_sessions принимает { init_data: string },
  возвращает { access_token, refresh_token, client: { id, phone, name, has_phone } }.
  Остальные эндпоинты (меню, корзина, заказы, адреса, промо) — те же, что использует
  pirosmani-frontend (см. ../pirosmani-frontend/src/services/api.ts как референс).
- Референсный проект для форка: ../pirosmani-frontend (React 19 + Vite + Tailwind CSS v4).
  Скопируй оттуда типы (src/types.ts), сервис api.ts (адаптируй под auth), и компоненты/
  страницы, указанные в плане (раздел 2.7).

ЗАДАЧА: создать новый проект pirosmani-telegram-app (рядом с pirosmani-backend и
pirosmani-frontend, НЕ внутри них) и реализовать этапы 4.4–4.12 из таблицы
"Часть 4: Порядок реализации" плана.

СТРОГИЕ ОГРАНИЧЕНИЯ:
1. НЕ изменять ничего в pirosmani-backend — она уже готова и протестирована (456 examples,
   0 failures). Если кажется, что нужен новый backend-эндпоинт — остановись и спроси,
   а не добавляй его самостоятельно.
2. НЕ придумывать новые API-контракты. Использовать только эндпоинты, которые реально
   существуют в pirosmani-backend/config/routes.rb.
3. Токены (access/refresh) хранить ТОЛЬКО в памяти (React state), НЕ в localStorage —
   это явное архитектурное решение (раздел 2.2 плана), WebView эфемерен.
4. Платежи — обычная карточная форма (как в pirosmani-frontend/src/components/CardForm.tsx),
   НЕ Telegram Stars / openInvoice (см. открытый вопрос №4 плана).
5. Один бот на все сценарии (тот же токен, что уже используется для
   pirosmani_brest_delivery_bot в backend) — не создавать второй бот.
6. Все тексты интерфейса — на русском языке, в стиле существующего pirosmani-frontend.
7. TypeScript strict, без `any` без крайней необходимости.

ПОРЯДОК ДЕЙСТВИЙ (следуй строго по шагам, после каждого шага — `npm run build`
должен проходить без ошибок; не переходи к следующему шагу, если предыдущий не собирается):

Шаг 1 (соответствует 4.4 плана). Скаффолд проекта.
  - Создать pirosmani-telegram-app/ с package.json, vite.config.ts, tsconfig.json,
    index.html — по структуре из раздела 2.1 плана.
  - Установить зависимости: react@19, react-dom@19, vite, tailwindcss v4,
    @telegram-apps/sdk, @telegram-apps/sdk-react — ПРОВЕРИТЬ актуальные версии
    в npm registry на момент установки (план мог зафиксировать устаревшую версию ^2.0.0).
  - Скопировать src/types.ts из pirosmani-frontend без изменений.
  - Критерий готовности: `npm run build` собирает пустой проект без ошибок.

Шаг 2 (4.5). useTelegramAuth + api.ts.
  - Форкнуть src/services/api.ts из pirosmani-frontend, добавить метод
    telegramLogin(initData) -> POST /api/v1/telegram_sessions.
  - Реализовать src/hooks/useTelegramAuth.ts по сниппету раздела 2.2 плана.
  - Токены — в памяти (переменная в ApiService/модуле, не в localStorage).
  - Критерий готовности: авто-логин при монтировании App.tsx (мок initData в dev-режиме,
    т.к. вне Telegram WebView retrieveLaunchParams() бросит ошибку — обернуть в try/catch
    и показать fallback-экран "Откройте через Telegram").

Шаг 3 (4.6). useTelegramTheme + CSS-переменные.
  - Реализовать src/hooks/useTelegramTheme.ts и src/index.css по разделу 2.4 плана.
  - Критерий: в dev-режиме (вне Telegram) применяются fallback-цвета из index.css.

Шаг 4 (4.7). MenuPage.
  - Форкнуть pages/MenuPage.tsx из pirosmani-frontend, убрать BottomNav,
    адаптировать цвета на CSS-переменные из шага 3.
  - Критерий: страница рендерится с моковыми/реальными данными меню через api.ts.

Шаг 5 (4.8). CartPage + MainButton.
  - Форкнуть CartPage.tsx, реализовать useMainButton.ts (раздел 2.5 плана).
  - Критерий: изменение количества товаров в корзине обновляет текст MainButton.

Шаг 6 (4.9). CheckoutPage.
  - Форкнуть CheckoutPage.tsx (адреса, зоны доставки, слоты, промокоды, бонусы —
    вся эта логика уже есть в pirosmani-frontend, копировать максимально близко
    к оригиналу, меняя только UI-обёртку и кнопку оформления на MainButton).
  - Обязательно: если client.has_phone === false — показать экран запроса телефона
    (раздел 2.3 плана) ПЕРЕД чекаутом, вызвать Telegram.WebApp.requestContact(),
    повторно вызвать telegramLogin(initData) с телефоном.
  - Критерий: заказ с телефоном создаётся успешно (проверить в дев-инстансе backend).

Шаг 7 (4.10). OrdersPage — история заказов. Форк без изменений логики.

Шаг 8 (4.11, если ещё не сделано в шаге 6). Полный поток requestContact,
  включая обработку случая "телефон совпал с существующим Client" (просто
  проверить, что has_phone становится true и заказ проходит — сам линк аккаунтов
  уже сделан на backend, фронту достаточно корректно отправить initData повторно).

Шаг 9 (4.12). Настройка бота + подготовка к деплою.
  - Написать скрипт (bash или JS) для вызова setChatMenuButton через Bot API
    (сниппет в разделе 3.1 плана). Токен бота брать из переменной окружения,
    НЕ хардкодить.
  - Подготовить vite.config.ts для продакшен-билда, добавить README с инструкцией
    деплоя на Netlify/Vercel (переменные окружения: VITE_API_BASE_URL и т.п.).
  - Не выполнять реальный деплой самостоятельно (нет доступа к хостингу/DNS) —
    только подготовить конфиги и инструкцию.

ЧТО ДЕЛАТЬ ПРИ НЕОПРЕДЕЛЁННОСТИ:
Если план не даёт достаточной информации для конкретного шага (например, точный
API-контракт эндпоинта, которого нет в routes.rb) — остановись, зафиксируй вопрос
в комментарии TODO в коде и в отдельном файле NOTES.md, не изобретай поведение.

ПОСЛЕ КАЖДОГО ШАГА:
- `npm run build` должен проходить.
- `npm run lint` (если настроен eslint) без ошибок.
- Короткое summary: что сделано, какие файлы созданы/изменены.
```

---

## Чек-лист прогресса (для контроля со стороны Zoo/human-ревьюера)

- [ ] Шаг 1 — скаффолд `pirosmani-telegram-app`, `npm run build` проходит
- [ ] Шаг 2 — `useTelegramAuth`, `api.telegramLogin`, авто-логин с fallback вне Telegram
- [ ] Шаг 3 — `useTelegramTheme`, CSS-переменные, fallback-тема
- [ ] Шаг 4 — `MenuPage` рендерится с реальными данными
- [ ] Шаг 5 — `CartPage` + `MainButton` синхронизированы
- [ ] Шаг 6 — `CheckoutPage` + поток `requestContact` перед первым заказом
- [ ] Шаг 7 — `OrdersPage`
- [ ] Шаг 8 — сквозная проверка связывания аккаунта по телефону
- [ ] Шаг 9 — скрипт `setChatMenuButton`, README по деплою

## Что НЕ входит в задачу DeepSeek (оставлено для совместной проработки)

- Реальный деплой на Netlify/Vercel и настройка DNS/домена.
- Fire-drill тест с реальным ботом и реальным Telegram-аккаунтом (этап 4.14 плана).
- Решение открытых архитектурных вопросов, если возникнут новые (например, если
  окажется, что нужен новый backend-эндпоинт).
- Дизайн-ревью визуальной адаптации под тему Telegram (светлая/тёмная) — см.
  отдельный вопрос про Figma-макет ниже.

---

## Ревью реализации DeepSeek

> Дата ревью: см. историю коммитов. Ревьюер: Zoo (Claude Sonnet). Все найденные
> проблемы ниже **уже исправлены** в коде (backend + `pirosmani-telegram-app`),
> тесты бекенда прогнаны: `464 examples, 0 failures`.

### 🔴 Критическая находка: `requestContact` был полностью фиктивным

Исходная реализация DeepSeek в `PhoneRequestScreen.tsx` делала следующее:

```tsx
<button onClick={onPhoneShared}>Поделиться номером</button>
```

Кнопка **не вызывала никакого Telegram API** — просто сразу дёргала callback
"успеха". Дальше в `App.tsx`:

```tsx
const handlePhoneShared = async () => {
  if (w?.Telegram?.WebApp?.initData) {
    await reauthenticate(w.Telegram.WebApp.initData)  // ← та же initData, без изменений!
  }
  setPage('checkout')  // ← переход БЕЗУСЛОВНО, даже если телефон не появился
}
```

Проблема глубже, чем просто "забыли вызвать функцию" — она вскрывает **ошибку
в самом исходном плане** (`telegram-mini-app-plan.md`, раздел 2.3, шаг 4):
план предполагал, что после `Telegram.WebApp.requestContact()` номер телефона
появится **внутри** `initData` при повторном чтении. Это технически неверно:

- `Telegram.WebApp.requestContact()` (в `@telegram-apps/sdk` v3 — функция
  `requestContact()`/`requestContactComplete()`) возвращает **отдельный,
  самостоятельно подписанный объект** `{ contact: {...}, auth_date, hash }`.
- `initData`/`initDataRaw` **не изменяется** после вызова этой функции — это
  статичные параметры запуска Mini App, полученные один раз при открытии.
- Соответственно, повторная отправка старой `initData` на backend просто
  возвращает того же клиента с тем же `has_phone: false` — цикл замкнут,
  ничего не работает, но код "притворяется", что работает (переходит на
  checkout), пока `Api::V1::OrdersController#create` не отклонит заказ.

**Итог**: фича "запрос телефона" из раздела 2.3 плана была **нефункциональной
заглушкой**, маскирующейся под работающий UI. Backend-защита (`current_client
.phone.present?` в `OrdersController`) не позволила бы создать заказ без
телефона, но пользователь доходил до последнего шага чекаута зря.

### ✅ Исправление

**Backend** — добавлена независимая проверка подписи контакта:
- [`Auth::TelegramWebAppService.verify_contact!`](../../pirosmani-backend/app/services/auth/telegram_web_app_service.rb:1) —
  проверяет HMAC подписи объекта `RequestedContact` (тот же секрет
  `HMAC-SHA256("WebAppData", bot_token)`, тот же алгоритм сборки check-string,
  что и для `initData` — Telegram использует единый механизм подписи для всех
  WebApp-payload'ов), плюс сверяет `user_id` внутри `contact` с
  `telegram_user_id` уже аутентифицированного клиента (защита от подмены
  номера чужого пользователя).
- [`Api::V1::TelegramSessionsController#link_phone_from_contact`](../../pirosmani-backend/app/controllers/api/v1/telegram_sessions_controller.rb:1) —
  новый необязательный параметр `contact_data` в том же `POST
  /api/v1/telegram_sessions`. При успешной проверке:
  - если номер свободен — привязывается к текущему `Client`;
  - если номер уже занят **другим** `Client` (человек уже заказывал через
    обычный телефон+OTP) — `telegram_user_id` переносится на существующий
    аккаунт, временная запись без истории удаляется (не оставляем "мёртвые"
    строки `Client` без единого идентификатора);
  - если у клиента, запросившего перенос, уже есть заказы/бонусы — перенос
    НЕ выполняется автоматически, конфликт логируется для ручной проверки
    (слишком рискованно молча резать историю без явного решения).
- Тесты: 3 новых кейса в [`spec/requests/api/v1/telegram_sessions_spec.rb`](../../pirosmani-backend/spec/requests/api/v1/telegram_sessions_spec.rb:1)
  + 5 в [`spec/services/auth/telegram_web_app_service_spec.rb`](../../pirosmani-backend/spec/services/auth/telegram_web_app_service_spec.rb:1).

**Frontend** — реальный вызов Telegram API:
- [`src/hooks/useRequestContact.ts`](../../pirosmani-telegram-app/src/hooks/useRequestContact.ts:1) —
  вызывает `requestContactComplete()` из `@telegram-apps/sdk-react`,
  с проверкой `isAvailable()`, обрабатывает 3 исхода: `granted` (возвращает
  `raw` подписанную строку) / `denied` (пользователь отклонил) / `unavailable`.
- [`src/hooks/useTelegramAuth.ts`](../../pirosmani-telegram-app/src/hooks/useTelegramAuth.ts:1) —
  метод `linkPhone(contactDataRaw)` отправляет `contact_data` вместе с
  сохранённой `initDataRaw` на `POST /api/v1/telegram_sessions`, возвращает
  `true` только если backend подтвердил `has_phone: true`.
- [`src/pages/PhoneRequestScreen.tsx`](../../pirosmani-telegram-app/src/pages/PhoneRequestScreen.tsx:1) —
  кнопка реально запрашивает контакт, показывает ошибку при отказе, кнопка
  "Пропустить" явно отделена от "Поделиться номером".
- `App.tsx` переходит на `checkout` **только** если `linkPhone` вернул `true` —
  иначе пользователь остаётся на экране запроса телефона с понятной ошибкой,
  а не проваливается в чекаут, который всё равно откажет.

### 🟡 Средняя находка: `MainButton` мимо SDK

`useMainButton` дёргал `window.Telegram.WebApp.MainButton` напрямую в
`try/catch`, полностью игнорируя то, что в проекте уже установлен
`@telegram-apps/sdk` именно для этого. Проблемы такого подхода:
- Нет проверок `isAvailable()` — в неподдерживаемой среде тихо ничего не
  происходит без единого сигнала, что что-то не так.
- Нет явного mount/unmount жизненного цикла, который сама библиотека
  использует для восстановления состояния кнопки между экранами.
- Несогласованность: `retrieveLaunchParams()` в `useTelegramAuth` — из SDK,
  а `MainButton` — мимо него. Это ровно тот тип несогласованности, который
  я предполагал в изначальном ревью плана ("актуальность API SDK нужно
  сверить").

**Исправлено**: `useMainButton` переписан на `mountMainButton`/
`setMainButtonParams`/`onMainButtonClick`/`offMainButtonClick`/
`unmountMainButton` из `@telegram-apps/sdk-react`, с явными проверками
`isAvailable()` перед каждым вызовом.

### ✅ Backend HMAC/replay — проверено, проблем не найдено

Отдельно проверил [`Auth::TelegramWebAppService.verify!`](../../pirosmani-backend/app/services/auth/telegram_web_app_service.rb:1)
(уже существовавший до ревью код):

- Алгоритм проверки подписи `initData` — корректен, соответствует
  [официальной спецификации Telegram](https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app):
  сортировка параметров → `"key=value"` через `\n` → `HMAC-SHA256(bot_token,
  "WebAppData")` как секрет → `HMAC-SHA256(secret, check_string)` → сравнение.
- `ActiveSupport::SecurityUtils.secure_compare` — timing-safe сравнение,
  защита от timing-атак при переборе хэша. ✓
- `MAX_AUTH_AGE = 24.hours` — разумное значение, соответствует рекомендации
  Telegram проверять свежесть `auth_date` (точное окно не регламентировано
  Telegram, 24ч — общепринятая практика).
- Единственное замечание (не баг, архитектурная заметка): фоллбэк-поиск
  клиента по `params["phone"]` внутри `verify!` (шаг 7 из исходного плана,
  раздел 1.2) технически недостижим в реальности — Telegram не передаёт
  `phone` внутри обычной `initData` (см. находку выше про `requestContact`).
  Этот код не вредит (просто никогда не сработает при живом трафике), но
  реальное связывание аккаунтов по телефону теперь происходит через новый
  `verify_contact!`/`contact_data`, а не через этот путь. Оставлен как есть —
  удаление потребовало бы трогать уже покрытый тестами код без функциональной
  необходимости.

### Осталось для совместной проработки (требуют реальной инфраструктуры/устройства)

1. **Реальный деплой на Netlify/Vercel + DNS** — нужен доступ к хостинг-аккаунту
   и домену `app.pirosmani.by` (или аналогичному), которого у меня нет.
   Чек-лист готов в [`pirosmani-telegram-app/README.md`](../../pirosmani-telegram-app/README.md:1).
2. **Fire-drill тест с реальным ботом и Telegram-аккаунтом** (этап 4.14
   основного плана) — требует физического устройства с Telegram и
   развёрнутого по HTTPS приложения. Именно на этом шаге нужно на практике
   проверить:
   - Реальный внешний вид `MainButton`/`BackButton` в разных клиентах
     (iOS/Android/Desktop) — визуальная имитация в прототипе была лишь
     приближением (см. `telegram-mini-app-prototype-prompt.md`).
   - Что `requestContactComplete()` действительно возвращает `raw`-строку в
     ожидаемом формате (query-string с полями `contact`, `auth_date`, `hash`) —
     реализация backend-проверки (`verify_contact!`) написана по аналогии с
     `initData` и покрыта юнит-тестами с искусственно собранными данными, но
     **не проверена против реального payload от живого Telegram-клиента**.
     Это единственный оставшийся риск в цепочке привязки телефона.
3. **Настройка бота** (`setChatMenuButton`) — скрипт готов
   ([`scripts/set-bot-menu.sh`](../../pirosmani-telegram-app/scripts/set-bot-menu.sh:1)),
   но требует реального `TELEGRAM_BOT_TOKEN` и опубликованного HTTPS URL
   (зависит от пункта 1).
