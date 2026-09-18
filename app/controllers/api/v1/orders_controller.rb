# app/controllers/api/v1/orders_controller.rb
module Api
  module V1
    class OrdersController < BaseController
      before_action :require_client!

      def index
        orders = current_client.orders
                                .includes(order_items: [:menu_item, :order_item_addons])
                                .order(created_at: :desc)
        render json: orders.map { |order| OrderSerializer.new(order).as_json }
      end

      def show
        order = current_client.orders
                               .includes(order_items: [:menu_item, :order_item_addons])
                               .find(params[:id])
        render json: OrderSerializer.new(order).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      end

      def create
        order = build_order

        delivery_price = resolve_delivery_price(order)
        return render json: { error: delivery_price[:error] }, status: delivery_price[:status] if delivery_price[:error]

        order.delivery_price = delivery_price[:value]
        items_total = calculate_items_total(order_items_params)
        order.total_price = apply_promo(items_total, order) + order.delivery_price

        Order.transaction do
          order.save!
          order.promo_code&.increment_usage!
          create_order_items!(order)
        end

        render json: OrderSerializer.new(order.reload).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "One of the menu items or addons was not found" }, status: :not_found
      end

      private

      def require_client!
        return if current_client.present?

        render json: { error: "Authorization required" }, status: :unauthorized
      end

      def build_order
        order = Order.new(order_params)
        order.client = current_client
        order.status = "pending"

        if order.order_type_delivery?
          assign_delivery_address(order)
        end

        order
      end

      def assign_delivery_address(order)
        if params.dig(:order, :client_address_id).present?
          order.client_address = current_client.client_addresses.find(params[:order][:client_address_id])
          order.address ||= order.client_address.full_address
        end
      end

      def resolve_delivery_price(order)
        return { value: 0.0 } if order.order_type_pickup?

        zone = order.delivery_zone || resolve_zone_from_params(order)
        return { error: "Delivery not available here", status: :unprocessable_entity } unless zone

        order.delivery_zone = zone

        if AppSettingsService.use_yandex_delivery?
          { value: (params.dig(:order, :estimated_cost) || 0.0).to_f }
        elsif zone.price.present?
          { value: zone.price.to_f }
        else
          { error: "Zone price is missing for internal delivery", status: :unprocessable_entity }
        end
      end

      def resolve_zone_from_params(order)
        lat = params.dig(:order, :lat)&.to_f || order.client_address&.lat&.to_f
        lng = params.dig(:order, :lng)&.to_f || order.client_address&.lng&.to_f
        return nil unless lat && lng

        DeliveryZone.active.find { |z| z.contains_point?(lat, lng) }
      end

      def create_order_items!(order)
        order_items_params.each do |item_params|
          menu_item = MenuItem.find(item_params[:menu_item_id])
          order_item = order.order_items.create!(
            menu_item: menu_item,
            quantity: item_params[:quantity].to_i,
            price: menu_item.price
          )

          Array(item_params[:addon_ids]).each do |addon_id|
            addon = Addon.find(addon_id)
            order_item.order_item_addons.create!(addon: addon)
          end
        end
      end

      def calculate_items_total(items)
        items.sum do |item|
          menu_item = MenuItem.find(item[:menu_item_id])
          item_total = menu_item.price * item[:quantity].to_i

          addon_ids = Array(item[:addon_ids])
          addons_total = Addon.where(id: addon_ids).sum(:price) * item[:quantity].to_i

          item_total + addons_total
        end
      end

      def apply_promo(items_total, order)
        return items_total unless order.promo_code

        order.promo_code.apply_to(items_total)
      end

      def order_params
        params.require(:order).permit(:order_type, :address, :scheduled_at, :client_address_id, :promo_code_id)
      end

      def order_items_params
        params.require(:order).require(:order_items).map do |item|
          item.permit(:menu_item_id, :quantity, addon_ids: [])
        end
      end
    end
  end
end
