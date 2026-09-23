module Admin
  module V1
    class DeliveryZonesController < Admin::BaseController
      before_action :set_delivery_zone, only: [:show, :update, :destroy]

      def index
        zones = DeliveryZone.order(created_at: :desc)
        render json: zones.map { |z| DeliveryZoneSerializer.new(z).as_json }
      end

      def show
        render json: DeliveryZoneSerializer.new(@delivery_zone).as_json
      end

      def create
        zone = DeliveryZone.new(delivery_zone_params)
        if zone.save
          render json: DeliveryZoneSerializer.new(zone).as_json, status: :created
        else
          render json: { errors: zone.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @delivery_zone.update(delivery_zone_params)
          render json: DeliveryZoneSerializer.new(@delivery_zone).as_json
        else
          render json: { errors: @delivery_zone.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @delivery_zone.destroy
        head :no_content
      end

      private

      def set_delivery_zone
        @delivery_zone = DeliveryZone.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Delivery zone not found" }, status: :not_found
      end

      def delivery_zone_params
        # coordinates — массив массивов [[lng, lat], ...], Strong Parameters не поддерживает
        # вложенные массивы через permit, поэтому берём напрямую
        permitted = params.require(:delivery_zone).permit(:name, :active, :price)
        raw_coords = params.dig(:delivery_zone, :coordinates)
        if raw_coords.is_a?(Array)
          permitted[:coordinates] = raw_coords.map { |pair| Array(pair).map(&:to_f) }
        end
        permitted
      end
    end
  end
end
