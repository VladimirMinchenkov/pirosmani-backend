# app/controllers/webhooks/yandex_delivery_controller.rb
# Приём статус-обновлений заявки от Yandex Delivery (claim.status_changed).
#
# TODO(live-verify): точная форма payload (поле claim_id vs order_id, вложенность
# status) — уточнить по факту первого живого вызова, см.
# YandexDeliveryClaimService. Пока разбираем оба разумных варианта формы,
# чтобы не сломаться на мелких отличиях версии API.
class Webhooks::YandexDeliveryController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    claim_id = payload_claim_id
    status = payload_status

    unless claim_id.present? && status.present?
      return render json: { error: "claim_id and status are required" }, status: :bad_request
    end

    order = Order.find_by(yandex_claim_id: claim_id)
    unless order
      # Заявка не найдена в нашей БД — отвечаем 200, чтобы Yandex не ретраил
      # бесконечно вебхук про заказ, которого у нас нет (например, уже удалён)
      Rails.logger.warn("[Webhooks::YandexDelivery] Unknown claim_id: #{claim_id}")
      return render json: { status: :ok }
    end

    order.update!(
      yandex_claim_status: status,
      courier_name: payload_courier_name || order.courier_name,
      courier_vehicle: payload_courier_vehicle || order.courier_vehicle,
      courier_phone_masked: payload_courier_phone || order.courier_phone_masked
    )

    render json: { status: :ok }
  end

  private

  def payload_claim_id
    params[:claim_id] || params.dig(:claim, :id)
  end

  def payload_status
    params[:status] || params.dig(:claim, :status) || params.dig(:new_status)
  end

  def payload_courier_name
    params.dig(:performer, :name) || params.dig(:claim, :performer, :name)
  end

  def payload_courier_vehicle
    car = params.dig(:performer, :car) || params.dig(:claim, :performer, :car)
    return nil unless car

    [car[:model], car[:number]].compact.join(" · ").presence
  end

  def payload_courier_phone
    params.dig(:performer, :phone_masked) || params.dig(:claim, :performer, :phone_masked)
  end
end
