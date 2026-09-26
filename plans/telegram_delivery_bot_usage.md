# Пошаговая инструкция: проверка Telegram-уведомлений о заказах на реальном боте

Разбито на два уровня: **Уровень A** — проверить, что сообщения с кнопками приходят (без вебхука, 5 минут). **Уровень B** — проверить, что нажатие кнопок реально меняет статус заказа (нужен публичный URL, туннель).

---

## Уровень A — отправка сообщения (без вебхука)

### Шаг 1. Создать бота

В Telegram открыть `@BotFather` → `/newbot` → задать имя → получить токен вида `123456789:AAH...`.

### Шаг 2. Положить токен в Rails credentials

```bash
cd ../pirosmani-backend
EDITOR="code --wait" bin/rails credentials:edit
```

Добавить:

```yaml
telegram:
  pirosmani_brest_delivery_bot_token: "123456789:AAH..."
```

Именно этот путь читает [`TelegramOrderNotifierService#bot_token`](app/services/telegram_order_notifier_service.rb) (см. `Rails.application.credentials.dig(:telegram, :pirosmani_brest_delivery_bot_token)`).

### Шаг 3. Создать группу/канал и получить её `chat_id`

1. Создать группу в Telegram (например «Пиросмани — заказы»).
2. Добавить туда своего бота как участника (для канала — как администратора).
3. Отправить в группу любое сообщение (просто "тест").
4. Открыть в браузере:
   ```
   https://api.telegram.org/bot<ТВОЙ_ТОКЕН>/getUpdates
   ```
5. В JSON-ответе найти `"chat":{"id": -1001234567890, ...}` — это и есть `chat_id` (для групп он отрицательный).

### Шаг 4. Сохранить `chat_id` в AppSetting

Через `bin/rails console`:

```ruby
AppSetting.find_or_create_by!(key: "telegram_orders_chat_id").update!(value: "-1001234567890")
```

Читается через [`AppSettingsService.telegram_orders_chat_id`](app/services/app_settings_service.rb).

### Шаг 5. Проверить отправку

Проще всего прямо из консоли, без создания реального заказа:

```ruby
order = Order.last # любой существующий заказ с order_items
TelegramOrderNotifierService.notify_new_order!(order)
```

Ожидаемый результат: в группе появляется сообщение с составом заказа и двумя кнопками — «✅ Принять» / «❌ Отклонить» ([`TelegramOrderNotifierService#keyboard`](app/services/telegram_order_notifier_service.rb)). Если сообщение не пришло — проверить `configured?` (токен и chat_id оба должны быть заполнены), либо смотреть `Rails.logger.error` в консоли/логах — метод специально не бросает исключение наружу (`rescue StandardError`).

Если запустить локальный сервер (`bin/rails s`) и создать заказ через фронтенд/Postman на `POST /api/v1/orders` — сообщение придёт автоматически, это уже подключено в [`Api::V1::OrdersController#create`](app/controllers/api/v1/orders_controller.rb).

На этом этапе кнопки в Telegram **видны**, но нажатие на них пока ничего не сделает — Telegram не может достучаться до `localhost`.

---

## Уровень B — проверка нажатия кнопок (нужен публичный URL)

### Шаг 6. Поднять туннель до локального Rails

```bash
ngrok http 3000
```

Скопировать выданный HTTPS-адрес, например `https://a1b2c3d4.ngrok-free.app`.

### Шаг 7. Зарегистрировать вебхук в Telegram

```bash
curl "https://api.telegram.org/bot<ТОКЕН>/setWebhook?url=https://a1b2c3d4.ngrok-free.app/webhooks/telegram"
```

Путь `/webhooks/telegram` — это маршрут [`config/routes.rb`](config/routes.rb), обрабатывается [`Webhooks::TelegramController#create`](app/controllers/webhooks/telegram_controller.rb).

Проверить, что вебхук встал:

```bash
curl "https://api.telegram.org/bot<ТОКЕН>/getWebhookInfo"
```

В ответе должен быть тот же `url` и `pending_update_count: 0`, без `last_error_message`.

### Шаг 8. Отправить тестовый заказ и нажать кнопку

1. Создать заказ (через фронт или консоль, как в Шаге 5) — придёт сообщение с кнопками.
2. В Telegram нажать «✅ Принять».
3. Ожидаемо:
   - Всплывающее уведомление в Telegram «Заказ принят ✅» (это [`answerCallbackQuery`](app/services/telegram_order_notifier_service.rb), обязательный шаг Bot API — без него кнопка визуально «висит»).
   - Сообщение в группе редактируется — текст обновляется, кнопки исчезают (статус `confirmed` попадает в `actionable?` → `false`, см. [`TelegramOrderNotifierService#actionable?`](app/services/telegram_order_notifier_service.rb)).
   - В БД у заказа `status == "confirmed"` — проверить в `rails console`: `Order.last.status`.
4. Проверить логи `rails s` в терминале — там будет видно, что запрос дошёл до `Webhooks::TelegramController#create`.

### Шаг 9. Проверить кейс «Отклонить» на другом заказе

Аналогично, статус должен стать `cancelled`.

### Шаг 10. Снять вебхук после теста

Важно, иначе ngrok-туннель закрывшись оставит "битый" вебхук:

```bash
curl "https://api.telegram.org/bot<ТОКЕН>/deleteWebhook"
```

---

## Продакшен: secret_token (обязательно перед реальным запуском)

**Проблема**: без проверки подписи любой, кто узнает формат `callback_data`
(`order:42:confirm`), может отправить `POST /webhooks/telegram` напрямую и
изменить статус чужого заказа без реального нажатия кнопки в Telegram:

```bash
curl -X POST https://api.pirosmani.by/webhooks/telegram \
  -d '{"callback_query":{"id":"fake","data":"order:42:confirm"}}'
```

**Решение** — Telegram Bot API поддерживает `secret_token`: при каждом
запросе к вебхуку Telegram присылает заголовок
`X-Telegram-Bot-Api-Secret-Token`, который сверяется на стороне сервера
([`Webhooks::TelegramController#verify_telegram_signature!`](app/controllers/webhooks/telegram_controller.rb)).
Если secret_token не настроен в credentials — проверка молча отключена
(для обратной совместимости с локальной разработкой), поэтому **перед
продакшеном обязательно выполнить шаги ниже**.

### Шаг 11. Сгенерировать и сохранить secret_token

```bash
cd ../pirosmani-backend
EDITOR="code --wait" bin/rails credentials:edit
```

Добавить (случайная строка 16–32 символа, буквы/цифры/подчёркивания):

```yaml
telegram:
  pirosmani_brest_delivery_bot_token: "ТОКЕН_БОТА"
  webhook_secret_token: "случайная_строка_например_a1b2c3d4e5f6g7h8"
```

### Шаг 12. Указать secret_token при setWebhook

```bash
curl "https://api.telegram.org/bot<ТОКЕН>/setWebhook?url=https://api.pirosmani.by/webhooks/telegram&secret_token=случайная_строка_например_a1b2c3d4e5f6g7h8"
```

Значение `secret_token` в этом `curl` должно **точно совпадать** с тем, что
сохранено в credentials на Шаге 11 — иначе все запросы от настоящего
Telegram будут отклоняться с `403` (потому что заголовок не совпадёт).

### Шаг 13. Перезапустить Rails

Credentials читаются при старте процесса — после Шага 11 обязательно
перезапустить `bin/rails s` (или передеплоить), иначе старое значение
`webhook_secret_token` (`nil`) останется в памяти и проверка не заработает.

### Проверка

```bash
# Без заголовка — должен вернуть 403
curl -X POST https://api.pirosmani.by/webhooks/telegram \
  -H "Content-Type: application/json" \
  -d '{"update_id":123,"message":{"text":"test"}}'

# С правильным заголовком — должен вернуть 200 (как обычный апдейт от Telegram)
curl -X POST https://api.pirosmani.by/webhooks/telegram \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: случайная_строка_например_a1b2c3d4e5f6g7h8" \
  -d '{"update_id":123,"callback_query":{"id":"test","data":"order:1:confirm"}}'
```

Реальные запросы от Telegram всегда содержат правильный заголовок
автоматически — эта проверка невидима для легитимного трафика, только
блокирует поддельные запросы.

**TTL callback_data (опционально)**: можно дополнительно добавить в
`callback_data` timestamp истечения (`order:42:confirm:1695745200`) и
игнорировать нажатия старше 24 часов — защита от повторного использования
кнопки через неделю. Это добивка для параноиков — `secret_token` уже
закрывает основной вектор атаки (поддельные запросы от третьих лиц), TTL
не реализован в текущей версии и не является блокером для продакшена.

---

## Если что-то не работает — куда смотреть

| Симптом | Причина | Проверка |
|---|---|---|
| Сообщение вообще не приходит | Токен или chat_id не настроены | `AppSettingsService.telegram_orders_chat_id` и credentials в консоли |
| Сообщение приходит, но без кнопок или дублируется | Заказ уже был отправлен ранее (проверка `telegram_message_id`) | `Order.last.telegram_chat_id` / `telegram_message_id` |
| Кнопка нажимается, но ничего не происходит | Вебхук не настроен или ngrok-туннель закрыт | `getWebhookInfo`, поле `last_error_message` |
| В `getWebhookInfo` есть `last_error_message` | Rails-сервер не отвечает 200 или упал по ошибке | Логи `rails s`, проверить что `bin/rails s` запущен на порту, указанном в ngrok |
| Callback приходит, но статус не меняется | `order_id` в `callback_data` не совпадает ни с одним заказом | [`CALLBACK_DATA_PATTERN`](app/controllers/webhooks/telegram_controller.rb) match на `order:<id>:confirm|cancel` |

Для регрессионной проверки логики без реального похода в Telegram — соответствующие сценарии уже покрыты тестами: [`spec/services/telegram_order_notifier_service_spec.rb`](spec/services/telegram_order_notifier_service_spec.rb) и [`spec/requests/webhooks/telegram_spec.rb`](spec/requests/webhooks/telegram_spec.rb) — но они не заменяют "живую" проверку через реального бота, описанную выше, так как токен/chat_id и реальный формат ответа Telegram нужно проверить хотя бы раз вручную (см. TODO в шапке сервиса).