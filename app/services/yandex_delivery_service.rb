# app/services/yandex_delivery_service.rb
# Расчёт стоимости доставки через Yandex Delivery API v2
#
# Требуется Bearer-токен в credentials[:yandex_delivery][:api_key]
# Документация: https://yandex.ru/dev/delivery/
#
# Формат route_points: coordinates: [lon, lat] (долгота, широта)
# Ответ: { price: "10.20", currency_rules: {...}, eta: 5.73, zone_id: "brest" }
#
class YandexDeliveryService
  API_URL = "https://b2b.taxi.yandex.net/b2b/cargo/integration/v2/check-price".freeze

  class Error < StandardError; end

  # Возвращает { price: Float, estimated_minutes: Integer } или nil при ошибке
  def self.calculate(lat:, lng:)
    new.calculate(lat: lat, lng: lng)
  end

  def calculate(lat:, lng:)
    api_key = Rails.application.credentials.dig(:yandex_delivery, :api_key)
    return fallback_price unless api_key.present?

    uri = URI(API_URL)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request["Accept-Language"] = "ru"

    # Координаты кафе — из app_settings, fallback на хардкод
    cafe_lon = AppSetting.find_by(key: "cafe_lng")&.value&.to_f || 23.694566
    cafe_lat = AppSetting.find_by(key: "cafe_lat")&.value&.to_f || 52.090279

    request.body = {
      items: [
        {
          quantity: 1,
          size: { length: 0.3, width: 0.3, height: 0.3 },
          weight: 5.0,
          cost_value: "100.00",
          cost_currency: "BYN",
          droppof_point: 1,
          pickup_point: 0,
          title: "Еда"
        }
      ],
      route_points: [
        {
          # Точка А — кафе (lon, lat)
          coordinates: [ cafe_lon, cafe_lat ],
          type: "source",
          visit_order: 1
        },
        {
          # Точка Б — адрес клиента (lon, lat)
          coordinates: [ lng, lat ],
          type: "destination",
          visit_order: 2
        }
      ]
    }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      data = JSON.parse(response.body)
      price = data["price"]
      if price
        {
          price: price.to_f,
          estimated_minutes: data["eta"]&.to_f&.ceil || 45
        }
      else
        fallback_price
      end
    else
      Rails.logger.warn "[YandexDelivery] API error #{response.code}: #{response.body}"
      nil # возвращаем nil чтобы контроллер показал available: false
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    Rails.logger.warn "[YandexDelivery] Network error: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.warn "[YandexDelivery] Unexpected error: #{e.message}"
    nil
  end

  private

  # Fallback: если API недоступен, возвращаем цену из первой активной зоны
  def fallback_price
    zone = DeliveryZone.active.first
    {
      price: zone&.price.to_f || 5.0,
      estimated_minutes: 45
    }
  end
end
