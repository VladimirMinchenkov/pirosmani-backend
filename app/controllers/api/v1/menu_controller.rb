module Api
  module V1
    class MenuController < BaseController
      before_action :require_client!, only: [:personalized]

      # GET /api/v1/menu/personalized
      # Возвращает персонализированные блоки для главного экрана
      def personalized
        orders = current_client.orders
                                .includes(order_items: { menu_item: :menu_item_group })
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

          # Используем уже загруженные ассоциации (includes выше) — без доп. запросов
          all_available = last_order.order_items.all? { |oi| menu_item_available?(oi.menu_item) }

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

          top_ids = counts.sort_by { |_, count| -count }.first(4).map(&:first)
          # Батч-загрузка вместо N+1 (было MenuItem.find_by внутри map)
          menu_items_by_id = MenuItem.includes(:menu_item_group).where(id: top_ids).index_by(&:id)

          frequent = top_ids.map do |menu_item_id|
            mi = menu_items_by_id[menu_item_id]
            next unless menu_item_available?(mi)
            {
              menu_item_id: mi.id,
              name: mi.name,
              price: mi.price.to_f,
              image_url: mi.image_url,
              order_count: counts[menu_item_id]
            }
          end.compact

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

      def menu_item_available?(mi)
        return false unless mi&.available
        return false if mi.menu_item_group && !mi.menu_item_group.available
        true
      end
    end
  end
end
