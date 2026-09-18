module Admin
  module V1
    class AppSettingsController < Admin::BaseController
      def index
        settings = AppSetting.all.order(:key)
        render json: settings.map { |s| AppSettingSerializer.new(s).as_json }
      end

      def update
        setting = AppSetting.find(params[:id])
        if setting.update(app_setting_params)
          render json: AppSettingSerializer.new(setting).as_json
        else
          render json: { errors: setting.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "App setting not found" }, status: :not_found
      end

      private

      def app_setting_params
        params.require(:app_setting).permit(:value)
      end
    end
  end
end