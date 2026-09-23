# app/controllers/api/v1/delivery_zones_controller.rb
module Api
  module V1
    class DeliveryZonesController < BaseController
      # GET /api/v1/delivery_zones/active
      # Возвращает координаты всех активных зон для проверки на фронтенде через turf.js
      def active
        zones = DeliveryZone.active.map do |z|
          coords = z.coordinates || []
          # turf.js требует замкнутый полигон: первая точка == последняя
          closed_coords = if coords.length >= 3 && coords.first != coords.last
            coords + [coords.first]
          else
            coords
          end

          {
            id: z.id,
            name: z.name,
            price: z.price.to_f,
            coordinates: closed_coords # [[lng, lat], ...]
          }
        end

        render json: zones
      end
    end
  end
end
