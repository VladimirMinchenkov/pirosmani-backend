# app/services/order_status_update_service.rb
# Общая логика смены статуса заказа — раньше жила только внутри
# Admin::V1::OrdersController#update, но теперь статус можно поменять и из
# Telegram (inline-кнопки Принять/Отклонить, см. Webhooks::TelegramController),
# поэтому вынесена в отдельный сервис, чтобы не дублировать
# maybe_create_courier_claim! между HTTP-контроллером и вебхуком.
class OrderStatusUpdateService
  def self.update!(order, status:)
    new(order).update!(status: status)
  end

  def initialize(order)
    @order = order
  end

  # Возвращает true при успехе, false если валидация не прошла
  # (@order.errors будет заполнен для отображения)
  def update!(status:)
    previous_status = @order.status
    return false unless @order.update(status: status)

    maybe_create_courier_claim!(previous_status)
    TelegramOrderNotifierService.update_status!(@order)
    true
  end

  private

  # Когда кухня переводит заказ в "cooking" — фиксируем фактический момент
  # старта готовки и планируем вызов курьера через GoodJob на момент,
  # рассчитанный DeliveryTimingService (не сразу!), чтобы курьер приехал
  # синхронно с готовностью блюда — см. plans/scheduled-delivery-courier-timing.md.
  # Только для доставки и только если заявка ещё не создана.
  def maybe_create_courier_claim!(previous_status)
    return unless @order.order_type_delivery?
    return unless previous_status != "cooking" && @order.status == "cooking"
    return if @order.yandex_claim_id.present?

    cooking_started_at = Time.current
    claim_planned_at = DeliveryTimingService.claim_planned_at(cooking_started_at: cooking_started_at)

    @order.update!(cooking_started_at: cooking_started_at, claim_planned_at: claim_planned_at)
    ClaimCreationJob.set(wait_until: claim_planned_at).perform_later(@order.id)
  end
end
