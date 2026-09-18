module Api
  module V1
    class AppSettingsController < BaseController
      def index
        settings = AppSetting.all.order(:key)
        render json: settings.map { |s| { key: s.key, value: s.value } }
      end
    end
  end
end