# app/controllers/api/v1/delivery_estimate_controller.rb
module Api
  module V1
    class DeliveryEstimateController < BaseController
      def show
        lat = params[:lat]&.to_f
        lng = params[:lng]&.to_f

        unless lat && lng
          return render json: { error: 'lat and lng are required' }, status: :bad_request
        end

        if AppSettingsService.use_yandex_delivery?
          # Yandex Delivery API
          delivery = YandexDeliveryService.calculate(lat: lat, lng: lng)
          if delivery
            render json: {
              available: true,
              price: delivery[:price],
              estimated_minutes: delivery[:estimated_minutes]
            }
          else
            render json: { available: false, message: 'Yandex Delivery unavailable' }
          end
        else
          # Internal: цена по зоне доставки
          zone = DeliveryZone.active.find { |z| z.contains_point?(lat, lng) }
          if zone
            render json: {
              available: true,
              price: zone.price.to_f,
              zone_name: zone.name
            }
          else
            render json: { available: false, message: 'Address outside delivery zone' }
          end
        end
      end
    end
  end
end
