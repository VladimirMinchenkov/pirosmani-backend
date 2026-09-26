# app/services/app_settings_service.rb
class AppSettingsService
  def self.delivery_mode
    AppSetting.find_by(key: 'delivery_mode')&.value || 'yandex'
  end

  # Средние тайминги для расчёта, когда начинать готовку / вызывать курьера
  # (см. plans/scheduled-delivery-courier-timing.md)
  def self.avg_cooking_minutes
    (AppSetting.find_by(key: 'cafe_avg_cooking_minutes')&.value || '30').to_f
  end

  def self.avg_courier_arrival_minutes
    (AppSetting.find_by(key: 'cafe_avg_courier_arrival_minutes')&.value || '15').to_f
  end

  def self.avg_travel_minutes
    (AppSetting.find_by(key: 'cafe_avg_travel_minutes')&.value || '20').to_f
  end

  def self.delivery_buffer_minutes
    (AppSetting.find_by(key: 'cafe_delivery_buffer_minutes')&.value || '5').to_f
  end

  def self.use_yandex_delivery?
    delivery_mode == 'yandex'
  end

  def self.use_internal_delivery?
    delivery_mode == 'internal'
  end

  # Режим вызова курьера через Yandex Delivery Claims API. По ответу поддержки
  # Яндекса отдельного sandbox-контура НЕ существует — есть только один
  # (реальный) аккаунт; "тестирование" там означает реальную заявку с
  # реальным исполнителем (с последующей платной отменой до приезда на точку А
  # или инструкцией исполнителю не забирать физический товар). Поэтому режимов
  # только два:
  # - mock: без единого реального запроса к Яндексу, всё симулируется по времени
  # - real: единственный существующий (боевой) контур Yandex Delivery
  def self.yandex_courier_mode
    AppSetting.find_by(key: 'yandex_courier_mode')&.value || 'mock'
  end

  def self.yandex_courier_mock?
    yandex_courier_mode == 'mock'
  end

  def self.yandex_courier_real?
    !yandex_courier_mock?
  end
end
