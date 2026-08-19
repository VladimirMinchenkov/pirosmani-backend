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

        # Ищем первую активную зону, в которую попадает точка
        # Так как зон немного, перебор в Ruby быстрее и проще сложного SQL
        zone = DeliveryZone.active.find do |z|
          z.contains_point?(lat, lng)
        end

        if zone
          # Если у тебя фиксированная цена доставки, можно игнорировать цену из зоны
          # или брать её, если админ решит менять.
          render json: {
            available: true,
            price: 0, #zone.price.to_f, # Или константа 300.0, если цена фиксирована
            zone_id: zone.id,
            zone_name: zone.name
          }
        else
          render json: { 
            available: false, 
            message: 'Delivery is not available at this address' 
          }, status: :not_acceptable
        end
      end
    end
  end
end
