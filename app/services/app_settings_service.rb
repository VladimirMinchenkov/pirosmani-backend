# app/services/app_settings_service.rb
class AppSettingsService
  def self.delivery_mode
    AppSetting.find_by(key: 'delivery_mode')&.value || 'yandex'
  end

  def self.use_yandex_delivery?
    delivery_mode == 'yandex'
  end

  def self.use_internal_delivery?
    delivery_mode == 'internal'
  end

  # Режим вызова курьера через Yandex Delivery Claims API:
  # - mock: без единого реального запроса к Яндексу, всё симулируется по времени
  # - sandbox: тестовый контур Яндекса (нужны sandbox credentials)
  # - production: боевой контур
  def self.yandex_courier_mode
    AppSetting.find_by(key: 'yandex_courier_mode')&.value || 'mock'
  end

  def self.yandex_courier_mock?
    yandex_courier_mode == 'mock'
  end

  def self.yandex_courier_sandbox?
    yandex_courier_mode == 'sandbox'
  end
end
