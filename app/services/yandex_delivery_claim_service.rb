# app/services/yandex_delivery_claim_service.rb
# Создание и подтверждение заявки на курьера (Yandex Delivery Claims API v2).
#
# Режимы (AppSettingsService.yandex_courier_mode):
# - mock: без единого сетевого запроса, курьер/статус симулируются по времени
#         (см. MockCourierSimulator) — так можно строить весь пайплайн ДО того,
#         как придут тестовые credentials от поддержки Яндекса.
# - sandbox / production: реальные вызовы claims/create + claims/accept
#   (TODO: реализовать, когда появятся credentials; интерфейс уже готов принимать их)
class YandexDeliveryClaimService
  class Error < StandardError; end

  def self.create_and_accept!(order)
    new(order).create_and_accept!
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

  private

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

  def create_real!
    # TODO(yandex-sandbox): когда придут sandbox/production credentials —
    # POST /claims/create, затем POST /claims/accept, сохранить реальный claim_id
    # и первый статус от API. Пока честно сообщаем, что режим не готов.
    raise Error, "Real Yandex Claims API integration is not implemented yet (mode=#{AppSettingsService.yandex_courier_mode})"
  end
end
