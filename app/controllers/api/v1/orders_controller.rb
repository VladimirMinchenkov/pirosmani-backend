module Api
  module V1
    class OrdersController < BaseController
      def index
        orders = Order.includes(:order_items, :menu_items).order(created_at: :desc)
        render json: orders, include: :order_items
      end

      def show
        order = Order.includes(:order_items, :menu_items).find(params[:id])
        render json: order, include: :order_items
      end

      def create
        order = Order.new(order_params)
        order.status = "pending"

        total = 0

        order_items_params.each do |item|
          menu_item = MenuItem.find(item[:menu_item_id])
          quantity = item[:quantity].to_i

          order.order_items.build(
            menu_item: menu_item,
            quantity: quantity,
            price: menu_item.price
          )

          total += menu_item.price * quantity
        end

        order.total_price = total
        order.delivery_price ||= 0
        order.total_price += order.delivery_price

        if order.save
          render json: order, include: :order_items, status: :created
        else
          render json: { errors: order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def order_params
        params.require(:order).permit(:address, :phone, :delivery_price)
      end

      def order_items_params
        params.require(:order).require(:order_items).map do |item|
          item.permit(:menu_item_id, :quantity)
        end
      end
    end
  end
end