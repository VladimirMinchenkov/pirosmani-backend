# app/services/yandex_delivery_tracking_service.rb
# Чтение статуса/позиции/ETA курьера + маскированный звонок.
#
# mock-режим: всё считается на основе Order#claim_requested_at (см. MockCourierSimulator),
# без единого запроса к Яндексу.
# sandbox/production: реальные вызовы performer-position / points-eta / driver-voice-forwarding
# (TODO — когда появятся credentials).
class YandexDeliveryTrackingService
  ETA_MINUTES = 30.0

  def self.snapshot(order)
    new(order).snapshot
  end

  def self.call_courier(order)
    new(order).call_courier
  end

  def initialize(order)
    @order = order
  end

  # Единый снапшот для proxy-эндпоинтов (клиент + админка).
  # Возвращает nil, если заявка ещё не создана.
  def snapshot
    return nil unless @order.claim_requested_at

    status = current_status
    position = courier_position

    {
      claim_id: @order.yandex_claim_id,
      status_key: status[:key],
      status_label: status[:label],
      courier_name: @order.courier_name,
      courier_vehicle: @order.courier_vehicle,
      lat: position&.first,
      lng: position&.last,
      eta_minutes: eta_remaining_minutes
    }
  end

  def call_courier
    if AppSettingsService.yandex_courier_mock?
      { forwarding_number: @order.courier_phone_masked || "+375 29 000-00-00" }
    else
      # TODO(yandex-sandbox): IntegrationV2DriverVoiceForwarding
      raise YandexDeliveryClaimService::Error, "Real voice forwarding is not implemented yet"
    end
  end

  private

  def elapsed_minutes
    return 0.0 unless @order.claim_requested_at

    (Time.current - @order.claim_requested_at) / 60.0
  end

  def current_status
    if AppSettingsService.yandex_courier_mock?
      MockCourierSimulator.status_for(elapsed_minutes)
    else
      # TODO(yandex-sandbox): реальный статус приходит через вебхук и лежит в yandex_claim_status
      { key: @order.yandex_claim_status, label: @order.yandex_claim_status }
    end
  end

  def courier_position
    dest = destination_coords
    return nil unless dest

    if AppSettingsService.yandex_courier_mock?
      MockCourierSimulator.position_for(elapsed_minutes, from: cafe_coords, to: dest, eta_minutes: ETA_MINUTES)
    else
      nil # TODO(yandex-sandbox): IntegrationV2ClaimsPerformerPosition
    end
  end

  def eta_remaining_minutes
    if AppSettingsService.yandex_courier_mock?
      MockCourierSimulator.eta_remaining_minutes(elapsed_minutes, eta_minutes: ETA_MINUTES)
    else
      nil # TODO(yandex-sandbox): IntegrationV2ClaimsPointsEta
    end
  end

  def cafe_coords
    lat = AppSetting.find_by(key: "cafe_lat")&.value&.to_f || 52.090279
    lng = AppSetting.find_by(key: "cafe_lng")&.value&.to_f || 23.694566
    [lat, lng]
  end

  def destination_coords
    addr = @order.client_address
    return nil unless addr&.lat && addr&.lng

    [addr.lat.to_f, addr.lng.to_f]
  end
end
