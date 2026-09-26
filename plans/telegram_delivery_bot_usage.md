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

## Если что-то не работает — куда смотреть

| Симптом | Причина | Проверка |
|---|---|---|
| Сообщение вообще не приходит | Токен или chat_id не настроены | `AppSettingsService.telegram_orders_chat_id` и credentials в консоли |
| Сообщение приходит, но без кнопок или дублируется | Заказ уже был отправлен ранее (проверка `telegram_message_id`) | `Order.last.telegram_chat_id` / `telegram_message_id` |
| Кнопка нажимается, но ничего не происходит | Вебхук не настроен или ngrok-туннель закрыт | `getWebhookInfo`, поле `last_error_message` |
| В `getWebhookInfo` есть `last_error_message` | Rails-сервер не отвечает 200 или упал по ошибке | Логи `rails s`, проверить что `bin/rails s` запущен на порту, указанном в ngrok |
| Callback приходит, но статус не меняется | `order_id` в `callback_data` не совпадает ни с одним заказом | [`CALLBACK_DATA_PATTERN`](app/controllers/webhooks/telegram_controller.rb) match на `order:<id>:confirm|cancel` |

Для регрессионной проверки логики без реального похода в Telegram — соответствующие сценарии уже покрыты тестами: [`spec/services/telegram_order_notifier_service_spec.rb`](spec/services/telegram_order_notifier_service_spec.rb) и [`spec/requests/webhooks/telegram_spec.rb`](spec/requests/webhooks/telegram_spec.rb) — но они не заменяют "живую" проверку через реального бота, описанную выше, так как токен/chat_id и реальный формат ответа Telegram нужно проверить хотя бы раз вручную (см. TODO в шапке сервиса).