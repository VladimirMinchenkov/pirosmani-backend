# app/services/app_settings_service.rb
class AppSettingsService
  def self.delivery_mode
    @mode ||= AppSetting.find_by(key: 'delivery_mode')&.value || 'yandex'
  end
  
  def self.use_yandex_delivery?
    delivery_mode == 'yandex'
  end

  def self.use_internal_delivery?
    delivery_mode == 'internal'
  end
end
