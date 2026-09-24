module Admin
  module V1
    class AppSettingsController < Admin::BaseController
      def index
        settings = AppSetting.all.order(:key)
        render json: settings.map { |s| AppSettingSerializer.new(s).as_json }
      end

      def create
        setting = AppSetting.new(app_setting_create_params)
        if setting.save
          geocode_if_cafe_address(setting)
          render json: AppSettingSerializer.new(setting).as_json, status: :created
        else
          render json: { errors: setting.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        setting = AppSetting.find(params[:id])
        if setting.update(app_setting_params)
          geocode_if_cafe_address(setting)
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

      def app_setting_create_params
        params.require(:app_setting).permit(:key, :value)
      end

      def geocode_if_cafe_address(setting)
        return unless setting.key == "cafe_address" && setting.value.present?

        api_key = Rails.application.credentials.dig(:geoapify, :api_key)
        return if api_key.blank?

        search_query = setting.value.downcase.include?("брест") ? setting.value : "#{setting.value}, Брест, Беларусь"

        uri = URI("https://api.geoapify.com/v1/geocode/search")
        uri.query = URI.encode_www_form({
          text: search_query,
          apiKey: api_key,
          limit: 1,
          lang: "ru",
          format: "json",
          filter: "rect:23.4,52.0,24.1,52.2"
        })

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(Net::HTTP::Get.new(uri))
        data = JSON.parse(response.body)

        results = data["results"] || []
        if results.any?
          first = results.first
          AppSetting.find_or_initialize_by(key: "cafe_lat").update!(value: first["lat"].to_s)
          AppSetting.find_or_initialize_by(key: "cafe_lng").update!(value: first["lon"].to_s)
        end
      rescue => e
        Rails.logger.warn("Geoapify geocoding failed for cafe_address: #{e.message}")
      end
    end
  end
end