# app/services/yandex_delivery_tracking_service.rb
# Чтение статуса/позиции/ETA курьера + маскированный звонок.
#
# mock-режим: всё считается на основе Order#claim_requested_at (см. MockCourierSimulator),
# без единого запроса к Яндексу.
# real: реальные вызовы performer-position / points-eta / driver-voice-forwarding,
# с коротким TTL-кэшем (Rails.cache), чтобы не заDDoSить Yandex при открытом
# экране трекинга (клиент/админка поллят раз в 8–15 сек).
#
# TODO(live-verify): точные поля ответа performer-position/points-eta —
# уточнить по факту первого живого вызова (см. YandexDeliveryClaimService).
class YandexDeliveryTrackingService
  ETA_MINUTES = 30.0
  API_URL = "https://b2b.taxi.yandex.net/b2b/cargo/integration/v2".freeze
  CACHE_TTL = 10.seconds

  # Человекочитаемые лейблы для статусов реального Claims API (status приходит
  # через вебхук и лежит в Order#yandex_claim_status)
  STATUS_LABELS = {
    "new" => "Заявка создана",
    "estimating" => "Оцениваем стоимость",
    "ready_for_approval" => "Готово к подтверждению",
    "accepted" => "Заявка подтверждена",
    "performer_lookup" => "Ищем курьера",
    "performer_draft" => "Курьер назначается",
    "performer_found" => "Курьер назначен",
    "performer_not_found" => "Не нашли курьера",
    "pickup_arrived" => "Курьер у кафе",
    "ready_for_pickup_confirmation" => "Курьер забирает заказ",
    "pickuped" => "Курьер выехал",
    "delivering" => "Курьер в пути",
    "delivery_arrived" => "Курьер у клиента",
    "delivered" => "Доставлено",
    "delivered_finish" => "Доставлено",
    "returning" => "Возврат",
    "returned" => "Возвращено",
    "returned_finish" => "Возвращено",
    "cancelled" => "Отменено",
    "cancelled_by_taxi" => "Отменено перевозчиком",
    "failed" => "Ошибка доставки"
  }.freeze

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
      real_call_courier
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
      key = @order.yandex_claim_status
      { key: key, label: STATUS_LABELS[key] || key }
    end
  end

  def courier_position
    if AppSettingsService.yandex_courier_mock?
      dest = destination_coords
      return nil unless dest

      MockCourierSimulator.position_for(elapsed_minutes, from: cafe_coords, to: dest, eta_minutes: ETA_MINUTES)
    else
      real_performer_position
    end
  end

  def eta_remaining_minutes
    if AppSettingsService.yandex_courier_mock?
      MockCourierSimulator.eta_remaining_minutes(elapsed_minutes, eta_minutes: ETA_MINUTES)
    else
      real_points_eta
    end
  end

  # ─── real ───

  def real_performer_position
    return nil unless @order.yandex_claim_id.present?

    cached_fetch("courier_position/#{@order.yandex_claim_id}") do
      result = post("/claims/performer-position", body: { claim_id: @order.yandex_claim_id })
      point = result.dig("position") || {}
      lat = point["lat"]
      lon = point["lon"]
      lat && lon ? [lat.to_f, lon.to_f] : nil
    end
  rescue StandardError => e
    Rails.logger.warn("[YandexDeliveryTrackingService] performer-position failed: #{e.message}")
    nil
  end

  def real_points_eta
    return nil unless @order.yandex_claim_id.present?

    cached_fetch("courier_eta/#{@order.yandex_claim_id}") do
      result = post("/claims/points-eta", body: { claim_id: @order.yandex_claim_id })
      point = Array(result["route_points"]).find { |p| p["type"] == "destination" } || {}
      seconds = point["eta_sec"] || point["eta"]
      seconds ? (seconds.to_f / 60.0).ceil : nil
    end
  rescue StandardError => e
    Rails.logger.warn("[YandexDeliveryTrackingService] points-eta failed: #{e.message}")
    nil
  end

  def real_call_courier
    result = post("/driver-voice-forwarding", body: { claim_id: @order.yandex_claim_id })
    phone = result["phone"] || result.dig("connection", "phone")
    raise YandexDeliveryClaimService::Error, "Yandex did not return a forwarding phone" unless phone

    { forwarding_number: phone }
  rescue YandexDeliveryClaimService::Error
    raise
  rescue StandardError => e
    raise YandexDeliveryClaimService::Error, "Failed to get voice forwarding: #{e.message}"
  end

  def cached_fetch(key)
    Rails.cache.fetch("yandex_delivery/#{key}", expires_in: CACHE_TTL) { yield }
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

  def post(path, body:)
    uri = URI("#{API_URL}#{path}")
    uri.query = URI.encode_www_form(request_id: SecureRandom.uuid)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    raise "Yandex API error #{response.code} for #{path}: #{response.body}" unless response.code.to_i.between?(200, 299)

    response.body.present? ? JSON.parse(response.body) : {}
  end

  def api_key
    Rails.application.credentials.dig(:yandex_delivery, :api_key)
  end
end
