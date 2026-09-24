# app/jobs/claim_creation_job.rb
# Выполняется через GoodJob в момент order.claim_planned_at (см. DeliveryTimingService) —
# именно тогда нужно вызвать курьера, чтобы он приехал на кафе синхронно с
# готовностью блюда, независимо от того, ASAP заказ или предзаказ.
#
# Планируется из Admin::V1::OrdersController при фактическом переходе заказа
# в статус "cooking" (см. plans/scheduled-delivery-courier-timing.md).
class ClaimCreationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order
    return unless order.order_type_delivery?
    return if order.yandex_claim_id.present? # уже создана (идемпотентность)
    return if order.status == "cancelled"

    YandexDeliveryClaimService.create_and_accept!(order)
  rescue YandexDeliveryClaimService::Error => e
    Rails.logger.warn "[ClaimCreationJob] Failed for order #{order_id}: #{e.message}"
  end
end
