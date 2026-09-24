module Admin
  module V1
    class OrdersController < Admin::BaseController
      INCLUDES = [
        :client, :delivery_zone, :client_address, :promo_code,
        { order_items: [:menu_item, :combo, :order_item_addons] }
      ].freeze

      before_action :set_order, only: [:show, :update, :courier, :create_courier_claim, :call_courier]

      def index
        orders = Order.includes(INCLUDES).order(created_at: :desc)
        render json: orders.map { |order| OrderSerializer.new(order).as_json }
      end

      def show
        render json: OrderSerializer.new(@order).as_json
      end

      def update
        previous_status = @order.status

        if @order.update(order_params)
          maybe_create_courier_claim!(previous_status)
          render json: OrderSerializer.new(@order).as_json
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /admin/v1/orders/:id/courier
      # Статус заявки, контакты курьера, координаты (для своей карты в админке)
      def courier
        snapshot = YandexDeliveryTrackingService.snapshot(@order)
        if snapshot
          render json: snapshot.merge(courier_mode: AppSettingsService.yandex_courier_mode)
        else
          render json: { error: "Courier claim not created yet" }, status: :not_found
        end
      end

      # POST /admin/v1/orders/:id/create_courier_claim
      # Ручное создание заявки (retry), если авто-создание не сработало или заказ не delivery
      def create_courier_claim
        YandexDeliveryClaimService.create_and_accept!(@order)
        render json: YandexDeliveryTrackingService.snapshot(@order)
      rescue YandexDeliveryClaimService::Error => e
        render json: { error: e.message }, status: :service_unavailable
      end

      # POST /admin/v1/orders/:id/call_courier
      # Возвращает подменный номер (masked) для звонка курьеру
      def call_courier
        render json: YandexDeliveryTrackingService.call_courier(@order)
      rescue YandexDeliveryClaimService::Error => e
        render json: { error: e.message }, status: :service_unavailable
      end

      private

      def set_order
        @order = Order.includes(INCLUDES).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      end

      # Заявку на курьера создаём автоматически, когда кухня переводит заказ
      # в "cooking" — к моменту готовности блюда курьер уже должен быть в пути.
      # Только для доставки и только если заявка ещё не создана.
      def maybe_create_courier_claim!(previous_status)
        return unless @order.order_type_delivery?
        return unless previous_status != "cooking" && @order.status == "cooking"
        return if @order.yandex_claim_id.present?

        YandexDeliveryClaimService.create_and_accept!(@order)
      rescue YandexDeliveryClaimService::Error => e
        Rails.logger.warn "[YandexDeliveryClaim] Failed to auto-create claim for order #{@order.id}: #{e.message}"
      end

      def order_params
        params.require(:order).permit(:status)
      end
    end
  end
end
