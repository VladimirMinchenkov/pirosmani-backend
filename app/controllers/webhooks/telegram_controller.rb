# app/controllers/webhooks/telegram_controller.rb
# Приём обновлений от Telegram Bot API. MVP-объём (pirosmani-telegram-orders,
# см. plans/ecosystem-architecture.md) — только нажатия на inline-кнопки
# "Принять"/"Отклонить" под уведомлением о новом заказе (callback_query).
# Обычные текстовые сообщения боту в этом объёме не обрабатываются.
#
# Безопасность: без проверки подписи любой, кто знает формат callback_data
# ("order:42:confirm"), может отправить сюда фейковый POST и изменить статус
# чужого заказа без реального нажатия кнопки в Telegram. Защита —
# заголовок X-Telegram-Bot-Api-Secret-Token, который Telegram присылает при
# КАЖДОМ запросе к вебхуку, если secret_token был задан при setWebhook (см.
# plans/telegram_delivery_bot_usage.md, раздел "Продакшен: secret_token").
class Webhooks::TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  before_action :verify_telegram_signature!

  CALLBACK_DATA_PATTERN = /\Aorder:(?<order_id>\d+):(?<action>confirm|cancel)\z/

  def create
    callback = params[:callback_query]
    handle_callback(callback) if callback.present?

    # Всегда 200 — иначе Telegram будет бесконечно ретраить вебхук
    render json: { status: :ok }
  end

  private

  # Если secret_token не настроен в credentials — проверка отключена (чтобы
  # не ломать локальную разработку/старые окружения без него). В продакшене
  # secret_token ОБЯЗАТЕЛЕН — см. plans/telegram_delivery_bot_usage.md.
  def verify_telegram_signature!
    expected = Rails.application.credentials.dig(:telegram, :webhook_secret_token)
    return if expected.blank?

    actual = request.headers["X-Telegram-Bot-Api-Secret-Token"]

    unless actual.present? && ActiveSupport::SecurityUtils.secure_compare(actual, expected)
      Rails.logger.warn("[Webhooks::TelegramController] Invalid or missing X-Telegram-Bot-Api-Secret-Token")
      return render json: { error: "forbidden" }, status: :forbidden
    end
  end

  def handle_callback(callback)
    match = CALLBACK_DATA_PATTERN.match(callback[:data].to_s)
    return answer(callback[:id], "Неизвестная команда") unless match

    order = Order.find_by(id: match[:order_id])
    return answer(callback[:id], "Заказ не найден") unless order

    new_status = match[:action] == "confirm" ? "confirmed" : "cancelled"

    if OrderStatusUpdateService.update!(order, status: new_status)
      answer(callback[:id], new_status == "confirmed" ? "Заказ принят ✅" : "Заказ отклонён ❌")
    else
      answer(callback[:id], "Не удалось обновить статус")
    end
  end

  def answer(callback_query_id, text)
    TelegramOrderNotifierService.answer_callback!(callback_query_id, text)
  end
end
