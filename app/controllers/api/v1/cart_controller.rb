module Api
  module V1
    class CartController < BaseController
      # POST /api/v1/cart/calculate
      # Принимает корзину и возвращает расчёт скидок
      def calculate
        items = params[:items] || []
        delivery_type = params[:delivery_type] || 'delivery'
        promo_code = params[:promo_code].presence

        promo = promo_code ? PromoCode.active_now.find_by(code: promo_code.strip.upcase) : nil

        calc_items = items.map do |item|
          {
            menu_item_id: item[:menu_item_id].to_i,
            name: item[:name],
            quantity: item[:quantity].to_i,
            price: item[:price].to_f,
            combo_item: item[:combo_item] || false
          }
        end

        calculator = PromotionCalculator.new(calc_items, delivery_type: delivery_type, promo_code: promo)
        result = calculator.calculate

        render json: {
          items: result.items,
          subtotal: result.subtotal,
          item_discount: result.item_discount,
          order_discount: result.order_discount,
          pickup_discount: result.pickup_discount,
          promo_code_discount: result.promo_code_discount,
          total: result.total,
          promo_code: promo ? { code: promo.code, discount_type: promo.discount_type, discount_value: promo.discount_value.to_f } : nil
        }
      end
    end
  end
end