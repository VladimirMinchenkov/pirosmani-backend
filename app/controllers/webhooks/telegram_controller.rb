# app/controllers/webhooks/telegram_controller.rb
# Приём обновлений от Telegram Bot API. MVP-объём (pirosmani-telegram-orders,
# см. plans/ecosystem-architecture.md) — только нажатия на inline-кнопки
# "Принять"/"Отклонить" под уведомлением о новом заказе (callback_query).
# Обычные текстовые сообщения боту в этом объёме не обрабатываются.
class Webhooks::TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  CALLBACK_DATA_PATTERN = /\Aorder:(?<order_id>\d+):(?<action>confirm|cancel)\z/

  def create
    callback = params[:callback_query]
    handle_callback(callback) if callback.present?

    # Всегда 200 — иначе Telegram будет бесконечно ретраить вебхук
    render json: { status: :ok }
  end

  private

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
