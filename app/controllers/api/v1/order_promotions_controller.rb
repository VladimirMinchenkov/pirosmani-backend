module Api
  module V1
    class OrderPromotionsController < BaseController
      def active
        promo = OrderPromotion.current.first
        if promo
          render json: OrderPromotionSerializer.new(promo).as_json
        else
          render json: nil
        end
      end
    end
  end
end
