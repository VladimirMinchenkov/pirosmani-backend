# app/services/yandex_delivery_claim_service.rb
# Создание, подтверждение и отмена заявки на курьера (Yandex Delivery Claims API v2).
#
# Режимы (AppSettingsService.yandex_courier_mode):
# - mock: без единого сетевого запроса, курьер/статус симулируются по времени
#         (см. MockCourierSimulator) — так можно строить весь пайплайн без
#         реальных вызовов Яндекса.
# - real: единственный существующий (боевой) контур Yandex Delivery. По ответу
#         поддержки Яндекса отдельного sandbox НЕТ — "тестирование" там means
#         реальная заявка с реальным исполнителем, которую можно отменить
#         (возможно платно) до приезда на точку А, либо провести целиком с
#         инструкцией исполнителю не забирать физический товар. Поэтому перед
#         включением на реальных заказах нужен один контролируемый ручной
#         прогон (см. plans/yandex-delivery-courier-tracking.md).
#
# ВАЖНО: точные названия полей запроса/ответа claims/create, claims/accept,
# claims/cancel-info, claims/cancel основаны на документации Yandex Delivery
# Cargo API v2 и МОГУТ потребовать точечной коррекции по итогам первого
# живого вызова (см. TODO(live-verify) ниже) — WebMock-тесты фиксируют
# ожидаемый контракт, но не гарантируют 100% совпадения с реальным API до
# первого реального прогона.
class YandexDeliveryClaimService
  class Error < StandardError; end

  API_URL = "https://b2b.taxi.yandex.net/b2b/cargo/integration/v2".freeze

  def self.create_and_accept!(order)
    new(order).create_and_accept!
  end

  def self.cancel!(order, allow_paid: false)
    new(order).cancel!(allow_paid: allow_paid)
  end

  def initialize(order)
    @order = order
  end

  # Идемпотентно: если заявка уже создана — ничего не делает
  def create_and_accept!
    return @order if @order.yandex_claim_id.present?

    if AppSettingsService.yandex_courier_mock?
      create_mock!
    else
      create_real!
    end
  end

  # Отмена уже созданной заявки. Если отмена платная (курьер уже назначен и
  # едет к точке А), метод по умолчанию НЕ выполняет отмену и поднимает Error —
  # чтобы случайную/автоматическую отмену нельзя было выполнить без явного
  # подтверждения платы. Для fire-drill/admin-кнопки нужно передать allow_paid: true.
  def cancel!(allow_paid: false)
    return @order unless @order.yandex_claim_id.present?

    if AppSettingsService.yandex_courier_mock?
      cancel_mock!
    else
      cancel_real!(allow_paid: allow_paid)
    end
  end

  private

  # ─── mock ───

  def create_mock!
    snapshot = MockCourierSimulator.generate_courier_snapshot(@order.id)
    @order.update!(
      yandex_claim_id: "mock-#{SecureRandom.uuid}",
      yandex_claim_status: "new",
      courier_name: snapshot[:name],
      courier_vehicle: snapshot[:vehicle],
      courier_phone_masked: snapshot[:phone_masked],
      claim_requested_at: Time.current
    )
    @order
  end

  def cancel_mock!
    @order.update!(yandex_claim_status: "cancelled")
    @order
  end

  # ─── real ───

  def create_real!
    request_id = SecureRandom.uuid
    created = post("/claims/create", query: { request_id: request_id }, body: claim_create_body)

    claim_id = created["id"]
    raise Error, "Yandex Delivery did not return a claim id: #{created.inspect}" unless claim_id

    accepted = post(
      "/claims/accept/#{claim_id}",
      query: { request_id: SecureRandom.uuid },
      body: { version: created["version"] }
    )

    # Реальная цена заявки — то, что Yandex фактически спишет с кафе в конце
    # месяца, В ОТЛИЧИЕ от order.delivery_price (оценка check-price на
    # чекауте, которую видел и оплатил гость). Разрыв между ними — риск
    # бизнеса (см. plans/yandex-delivery-fire-drill-guide.md), поэтому
    # сохраняем обе цены для сравнения в админке, а не только для клиента.
    actual_price = extract_actual_price(created) || extract_actual_price(accepted)

    # Предварительное ETA до точки Б — доступно СРАЗУ из ответа claims/create,
    # не дожидаясь вебхука performer_found/points-eta. Показываем гостю
    # немедленно после оформления, вместо "точность появится позже".
    eta_minutes = extract_eta_minutes(created) || extract_eta_minutes(accepted)

    @order.update!(
      yandex_claim_id: claim_id,
      yandex_claim_status: accepted["status"] || created["status"] || "new",
      claim_requested_at: Time.current,
      yandex_actual_claim_price: actual_price,
      yandex_claim_eta_minutes: eta_minutes
    )
    @order
  rescue Error
    raise
  rescue StandardError => e
    Rails.logger.error("[YandexDeliveryClaimService] create_real! failed: #{e.message}")
    raise Error, "Failed to create Yandex Delivery claim: #{e.message}"
  end

  # TODO(live-verify): точное расположение цены в ответе claims/create нужно
  # уточнить по факту первого живого вызова — пробуем несколько разумных
  # вариантов структуры ответа Yandex Delivery Cargo API v2 (pricing.offer.price,
  # pricing.total_price, offer_price, price), ни один не считается финальным
  # до проверки на реальном аккаунте.
  def extract_actual_price(response)
    candidate =
      response.dig("pricing", "offer", "price") ||
      response.dig("pricing", "total_price") ||
      response.dig("pricing", "price") ||
      response["offer_price"] ||
      response["price"]

    candidate.present? ? candidate.to_s.to_f : nil
  end

  # TODO(live-verify): аналогично цене — точное расположение ETA в ответе
  # claims/create не подтверждено живым вызовом. Пробуем: верхнеуровневый
  # "eta" (секунды, как у check-price — см. YandexDeliveryService), запись
  # destination в route_points (eta_sec/eta), и pricing.offer.eta.
  def extract_eta_minutes(response)
    seconds =
      response["eta_sec"] ||
      destination_route_point(response)&.dig("eta_sec") ||
      destination_route_point(response)&.dig("eta")&.then { |v| v.to_f * 60 } ||
      response.dig("pricing", "offer", "eta_sec")

    minutes_from_seconds = seconds.present? ? (seconds.to_f / 60.0).ceil : nil
    return minutes_from_seconds if minutes_from_seconds

    # Верхнеуровневый "eta" в минутах (как у check-price/YandexDeliveryService)
    top_level_eta = response["eta"]
    top_level_eta.present? ? top_level_eta.to_f.ceil : nil
  end

  def destination_route_point(response)
    Array(response["route_points"]).find { |p| p["type"] == "destination" }
  end

  def cancel_real!(allow_paid:)
    claim_id = @order.yandex_claim_id

    info = post("/claims/cancel-info/#{claim_id}", query: { request_id: SecureRandom.uuid }, body: {})
    cancel_state = info["cancel_state"] # "free" | "paid"

    if cancel_state == "paid" && !allow_paid
      raise Error, "Cancellation is paid for this claim (cancel_state=paid) — pass allow_paid: true to confirm"
    end

    current = post("/claims/info/#{claim_id}", query: { request_id: SecureRandom.uuid }, body: {})

    post(
      "/claims/cancel/#{claim_id}",
      query: { request_id: SecureRandom.uuid },
      body: { version: current["version"], cancel_state: cancel_state }
    )

    @order.update!(yandex_claim_status: "cancelled")
    @order
  rescue Error
    raise
  rescue StandardError => e
    Rails.logger.error("[YandexDeliveryClaimService] cancel_real! failed: #{e.message}")
    raise Error, "Failed to cancel Yandex Delivery claim: #{e.message}"
  end

  # ─── request builders ───

  # TODO(live-verify): точная форма items/route_points/client_requirements для
  # claims/create — уточнить по факту первого живого вызова (см. header-комментарий)
  def claim_create_body
    {
      items: [
        {
          quantity: 1,
          size: { length: 0.3, width: 0.3, height: 0.3 },
          weight: 5.0,
          cost_value: order_items_cost.to_s,
          cost_currency: "BYN",
          title: "Заказ ##{@order.id}"
        }
      ],
      route_points: [source_point, destination_point],
      callback_url: webhook_url,
      client_requirements: { taxi_class: "courier" }
    }
  end

  def source_point
    {
      coordinates: [cafe_lng, cafe_lat],
      type: "source",
      visit_order: 1,
      contact: {
        name: AppSetting.find_by(key: "cafe_name")&.value || "Пиросмани",
        phone: AppSetting.find_by(key: "cafe_phone")&.value || ""
      },
      address: { fullname: AppSetting.find_by(key: "cafe_address")&.value || "" }
    }
  end

  def destination_point
    addr = @order.client_address
    {
      coordinates: [addr&.lng.to_f, addr&.lat.to_f],
      type: "destination",
      visit_order: 2,
      contact: {
        name: @order.client&.name.presence || "Клиент",
        phone: @order.client&.phone || ""
      },
      address: { fullname: addr&.full_address || @order.address || "" }
    }
  end

  def order_items_cost
    @order.total_price.to_f - @order.delivery_price.to_f
  end

  def cafe_lat
    AppSetting.find_by(key: "cafe_lat")&.value&.to_f || 52.090279
  end

  def cafe_lng
    AppSetting.find_by(key: "cafe_lng")&.value&.to_f || 23.694566
  end

  def webhook_url
    base = AppSetting.find_by(key: "public_base_url")&.value || Rails.application.credentials.dig(:app, :base_url)
    return nil if base.blank?

    "#{base}/webhooks/yandex_delivery"
  end

  # ─── HTTP ───

  def post(path, query:, body:)
    uri = URI("#{API_URL}#{path}")
    uri.query = URI.encode_www_form(query) if query.present?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request["Accept-Language"] = "ru"
    request.body = body.to_json

    response = http.request(request)
    raise_yandex_error!(response, path) unless response.code.to_i.between?(200, 299)

    response.body.present? ? JSON.parse(response.body) : {}
  end

  # Осмысленная причина отказа (например, "тариф недоступен для маршрута")
  # вместо голого дампа тела ответа — Yandex Cargo API обычно возвращает
  # структурированную ошибку с полем message/code. Если распарсить не
  # получилось — используем исходное тело как фолбэк, чтобы не потерять
  # диагностическую информацию.
  # TODO(live-verify): точная структура тела ошибки Yandex (message/code/
  # errors[].message) не подтверждена живым вызовом.
  def raise_yandex_error!(response, path)
    parsed = JSON.parse(response.body) rescue nil
    reason =
      parsed &&
      (parsed["message"] || parsed.dig("errors", 0, "message") || parsed["code"] || parsed["description"])

    detail = reason || response.body
    raise "Yandex API error #{response.code} for #{path}: #{detail}"
  end

  def api_key
    Rails.application.credentials.dig(:yandex_delivery, :api_key)
  end
end
