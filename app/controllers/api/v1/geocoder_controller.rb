module Api
  module V1
    class GeocoderController < BaseController
      GEOAPIFY_GEOCODE_URL = "https://api.geoapify.com/v1/geocode/search"
      GEOAPIFY_URL = "https://api.geoapify.com/v1/geocode/autocomplete"

      # GET /api/v1/geocoder?address=ул. Советская, 64, Брест
      # Прямое геокодирование через Geoapify
      def show
        address = params[:address]
        return render json: { error: "address is required" }, status: :bad_request if address.blank?

        api_key = Rails.application.credentials.dig(:geoapify, :api_key)
        return render json: { error: "Geoapify API key not configured" }, status: :service_unavailable if api_key.blank?

        # Добавляем "Брест" к запросу если не указан город
        search_query = address.downcase.include?("брест") ? address : "#{address}, Брест, Беларусь"

        uri = URI(GEOAPIFY_GEOCODE_URL)
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
        request = Net::HTTP::Get.new(uri)

        response = http.request(request)
        data = JSON.parse(response.body)

        results = data["results"] || []
        if results.any?
          first = results.first
          render json: {
            lat: first["lat"].to_f,
            lng: first["lon"].to_f,
            address: first["formatted"] || search_query
          }
        else
          render json: { error: "Address not found" }, status: :not_found
        end
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/geocoder/suggest?q=Советская
      # Автодополнение через Geoapify (бесплатно до 3000 запросов/день)
      def suggest
        query = params[:q]
        return render json: { error: "q is required" }, status: :bad_request if query.blank?

        api_key = Rails.application.credentials.dig(:geoapify, :api_key)
        return render json: { error: "Geoapify API key not configured" }, status: :service_unavailable if api_key.blank?

        uri = URI(GEOAPIFY_URL)
        uri.query = URI.encode_www_form({
          text: query,
          apiKey: api_key,
          limit: 6,
          lang: "ru",
          format: "json",
          filter: "rect:23.4,52.0,24.1,52.2", # Только Брест и окрестности (min_lon,min_lat,max_lon,max_lat)
        })

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri)

        response = http.request(request)
        data = JSON.parse(response.body)

        results = (data["results"] || []).map do |r|
          # Формируем короткий заголовок: "ул. Кирова, 21, Брест"
          parts = []
          parts << r["street"] if r["street"].present?
          parts << r["housenumber"] if r["housenumber"].present?
          city = r["city"] || r["town"] || r["village"]
          parts << city if city.present?

          title = parts.any? ? parts.join(", ") : (r["formatted"] || "")

          {
            title: title,
            subtitle: ""
          }
        end

        render json: { results: results }
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end