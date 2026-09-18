module Admin
  module V1
    class OrdersController < Admin::BaseController
      INCLUDES = [
        :client, :delivery_zone, :client_address, :promo_code,
        { order_items: [:menu_item, :order_item_addons] }
      ].freeze

      before_action :set_order, only: [:show, :update]

      def index
        orders = Order.includes(INCLUDES).order(created_at: :desc)
        render json: orders.map { |order| OrderSerializer.new(order).as_json }
      end

      def show
        render json: OrderSerializer.new(@order).as_json
      end

      def update
        if @order.update(order_params)
          render json: OrderSerializer.new(@order).as_json
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_order
        @order = Order.includes(INCLUDES).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      end

      def order_params
        params.require(:order).permit(:status)
      end
    end
  end
end
