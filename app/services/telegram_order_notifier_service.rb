# app/services/telegram_order_notifier_service.rb
# Уведомления о заказах в Telegram-канал/группу — MVP-замена стороннего
# платного бота (см. plans/ecosystem-architecture.md,
# pirosmani-telegram-orders): при создании заказа шлём сообщение с составом
# и inline-кнопками "Принять"/"Отклонить"; при смене статуса редактируем то
# же сообщение (editMessageText), а не шлём новое.
#
# Настройка: AppSettingsService.telegram_orders_chat_id (куда слать) +
# Rails.application.credentials.dig(:telegram, :pirosmani_brest_delivery_bot_token) (токен бота).
# Если что-то из этого не настроено — методы тихо ничего не делают (сбой
# уведомления НИКОГДА не должен ронять создание/обновление заказа).
#
# TODO(live-verify): формат ответа Telegram Bot API стабилен и документирован
# (в отличие от Yandex Delivery), но токен/chat_id нужно один раз проверить
# на реальном боте перед включением в production.
class TelegramOrderNotifierService
  API_URL = "https://api.telegram.org/bot".freeze

  def self.notify_new_order!(order)
    new(order).notify_new_order!
  end

  def self.update_status!(order)
    new(order).update_status!
  end

  def self.answer_callback!(callback_query_id, text)
    new(nil).answer_callback!(callback_query_id, text)
  end

  def initialize(order)
    @order = order
  end

  # Отправляет новое сообщение с составом заказа и кнопками Принять/Отклонить.
  # Сохраняет chat_id/message_id на заказ, чтобы позже редактировать именно
  # это сообщение при смене статуса.
  def notify_new_order!
    return unless configured?

    result = post("sendMessage", {
      chat_id: chat_id,
      text: message_text,
      parse_mode: "HTML",
      reply_markup: { inline_keyboard: keyboard }
    })

    message_id = result.dig("result", "message_id")
    @order.update!(telegram_chat_id: chat_id.to_s, telegram_message_id: message_id) if message_id
    true
  rescue StandardError => e
    Rails.logger.error("[TelegramOrderNotifierService] notify_new_order! failed: #{e.message}")
    false
  end

  # Редактирует ранее отправленное сообщение — новый статус в тексте, кнопки
  # убираются, если заказ уже принят/отклонён/выполнен (нет смысла нажимать снова)
  def update_status!
    return unless configured?
    return unless @order.telegram_chat_id.present? && @order.telegram_message_id.present?

    body = {
      chat_id: @order.telegram_chat_id,
      message_id: @order.telegram_message_id,
      text: message_text,
      parse_mode: "HTML"
    }
    body[:reply_markup] = { inline_keyboard: keyboard } if actionable?

    post("editMessageText", body)
    true
  rescue StandardError => e
    Rails.logger.error("[TelegramOrderNotifierService] update_status! failed: #{e.message}")
    false
  end

  # Убирает "часики"/спиннер с нажатой inline-кнопки у отправителя callback'а
  # и показывает всплывающее уведомление — обязательный шаг по Bot API,
  # иначе кнопка в Telegram-клиенте выглядит "зависшей".
  def answer_callback!(callback_query_id, text)
    return unless bot_token.present?

    post("answerCallbackQuery", { callback_query_id: callback_query_id, text: text })
    true
  rescue StandardError => e
    Rails.logger.error("[TelegramOrderNotifierService] answer_callback! failed: #{e.message}")
    false
  end

  private

  def configured?
    bot_token.present? && chat_id.present?
  end

  # Заказ ещё требует решения (не принят/не отклонён/не завершён) — только
  # тогда показываем кнопки
  def actionable?
    !%w[confirmed cancelled done].include?(@order.status)
  end

  def keyboard
    [[
      { text: "✅ Принять", callback_data: "order:#{@order.id}:confirm" },
      { text: "❌ Отклонить", callback_data: "order:#{@order.id}:cancel" }
    ]]
  end

  def message_text
    lines = ["<b>Заказ ##{@order.id}</b>"]
    lines << (@order.order_type_delivery? ? "🚚 Доставка" : "🏪 Самовывоз")
    lines << "📍 #{@order.client_address&.full_address || @order.address}" if @order.order_type_delivery?
    lines << "🗓 Предзаказ на #{@order.scheduled_at.strftime('%d.%m %H:%M')}" if @order.scheduled_at.present?

    lines << ""
    @order.order_items.each do |item|
      lines << "• #{item.display_name} × #{item.quantity}"
    end

    lines << ""
    lines << "Итого: <b>#{@order.total_price.to_f} BYN</b>"
    lines << ""
    lines << "Статус: #{status_label}"

    lines.join("\n")
  end

  def status_label
    {
      "pending" => "🕐 Ожидает подтверждения",
      "confirmed" => "✅ Принят",
      "cooking" => "👨‍🍳 Готовится",
      "delivering" => "🛵 В доставке",
      "done" => "✔️ Выполнен",
      "cancelled" => "❌ Отклонён"
    }[@order.status] || @order.status
  end

  def chat_id
    AppSettingsService.telegram_orders_chat_id
  end

  def post(method, body)
    uri = URI("#{API_URL}#{bot_token}/#{method}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    parsed = response.body.present? ? JSON.parse(response.body) : {}

    unless response.code.to_i.between?(200, 299) && parsed["ok"] != false
      raise "Telegram API error #{response.code} for #{method}: #{parsed['description'] || response.body}"
    end

    parsed
  end

  def bot_token
    Rails.application.credentials.dig(:telegram, :pirosmani_brest_delivery_bot_token)
  end
end
