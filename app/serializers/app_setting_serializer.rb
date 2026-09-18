# app/serializers/app_setting_serializer.rb
class AppSettingSerializer
  def initialize(app_setting)
    @app_setting = app_setting
  end

  def as_json(*)
    {
      id: @app_setting.id,
      key: @app_setting.key,
      value: @app_setting.value
    }
  end
end