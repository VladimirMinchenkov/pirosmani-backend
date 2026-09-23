# app/controllers/api/v1/promo_codes_controller.rb
module Api
  module V1
    class PromoCodesController < BaseController
      # POST /api/v1/promo_codes/validate — проверка промокода перед заказом
      def validate
        code = params[:code]
        return render json: { error: "code is required" }, status: :bad_request if code.blank?

        promo = PromoCode.active_now.find_by(code: code.strip.upcase)
        return render json: { valid: false, error: "Invalid or expired promo code" } unless promo

        return render json: { valid: false, error: "Minimum order price not met" } if params[:order_total].to_f < promo.min_order_price

        render json: {
          valid: true,
          code: promo.code,
          discount_type: promo.discount_type,
          discount_value: promo.discount_value.to_f
        }
      end
    end
  end
end