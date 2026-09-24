module Api
  module V1
    class MenuController < BaseController
      before_action :require_client!, only: [:personalized]

      # GET /api/v1/menu/personalized
      # Возвращает персонализированные блоки для главного экрана
      def personalized
        orders = current_client.orders
                                .includes(order_items: :menu_item)
                                .order(created_at: :desc)

        result = { order_count: orders.count }

        # Последний заказ → блок «Повторить»
        last_order = orders.first
        if last_order
          items = last_order.order_items.map do |oi|
            {
              menu_item_id: oi.menu_item_id,
              name: oi.menu_item.name,
              quantity: oi.quantity,
              price: oi.menu_item.price.to_f
            }
          end

          all_available = items.all? { |i| menu_item_available?(i[:menu_item_id]) }

          result[:repeat_order] = {
            id: last_order.id,
            total_price: last_order.total_price.to_f,
            delivery_price: last_order.delivery_price.to_f,
            created_at: last_order.created_at,
            items: items,
            all_available: all_available
          }
        else
          result[:repeat_order] = nil
        end

        # Часто заказываемые позиции (3+ заказов)
        if orders.count >= 3
          counts = Hash.new(0)
          orders.each do |o|
            o.order_items.each do |oi|
              counts[oi.menu_item_id] += oi.quantity
            end
          end

          frequent = counts
            .sort_by { |_, count| -count }
            .first(4)
            .map do |menu_item_id, count|
              mi = MenuItem.find_by(id: menu_item_id)
              next unless mi&.available
              {
                menu_item_id: mi.id,
                name: mi.name,
                price: mi.price.to_f,
                image_url: mi.image_url,
                order_count: count
              }
            end
            .compact

          result[:frequent_items] = frequent
        else
          result[:frequent_items] = []
        end

        render json: result
      end

      private

      def require_client!
        return if current_client.present?
        render json: { error: "Authorization required" }, status: :unauthorized
      end

      def menu_item_available?(id)
        mi = MenuItem.find_by(id: id)
        return false unless mi&.available
        return false if mi.menu_item_group && !mi.menu_item_group.available
        true
      end
    end
  end
end