
# app/controllers/api/v1/orders_controller.rb
module Api
  module V1
    class OrdersController < BaseController
      def create
        unless current_client.present?
          return render json: { error: 'Authorization required to place an order' }, status: :unauthorized
        end

        lat = params.dig(:order, :lat)&.to_f
        lng = params.dig(:order, :lng)&.to_f

        unless lat && lng
          return render json: { error: 'Coordinates required' }, status: :bad_request
        end

        zone = DeliveryZone.active.find do |z|
          z.contains_point?(lat, lng)
        end

        unless zone
          return render json: { error: 'Delivery not available here' }, status: :unprocessable_entity
        end

        delivery_price = 0.0

        if AppSetting.use_yandex_delivery?
          delivery_price = (params.dig(:order, :estimated_cost) || 0.0).to_f
        else
          if zone.price.present?
            delivery_price = zone.price.to_f
          else
            return render json: { error: 'Zone price is missing for internal delivery' }, status: :unprocessable_entity
          end
        end

        order = Order.new(order_params)
        order.client = current_client
        order.delivery_zone = zone
        order.status = 'pending'
        order.delivery_price = delivery_price

        total_items = calculate_items_total(order_items_params)
        order.total_price = total_items + delivery_price

        begin
          Order.transaction do
            order.save!

            order_items_params.each do |item_params|
              menu_item = MenuItem.find(item_params[:menu_item_id])
              order.order_items.create!(
                menu_item: menu_item,
                quantity: item_params[:quantity].to_i,
                price: menu_item.price
              )
            end
          end

          # Чистый JSON без зависимостей
          render json: {
            id: order.id,
            address: order.address,
            status: order.status,
            total_price: order.total_price,
            delivery_price: order.delivery_price,
            order_items: order.order_items.map do |oi|
              {
                id: oi.id,
                menu_item_id: oi.menu_item_id,
                name: oi.menu_item.name,
                quantity: oi.quantity,
                price: oi.price
              }
            end
          }, status: :created

        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: 'One of the menu items was not found' }, status: :not_found
        end
      end

      private

      def calculate_items_total(items)
        items.sum do |item|
          menu_item = MenuItem.find(item[:menu_item_id])
          menu_item.price * item[:quantity].to_i
        end
      end

      def order_params
        params.require(:order).permit(:address, :phone)
      end

      def order_items_params
        params.require(:order).require(:order_items).map do |item|
          item.permit(:menu_item_id, :quantity)
        end
      end
    end
  end
end
