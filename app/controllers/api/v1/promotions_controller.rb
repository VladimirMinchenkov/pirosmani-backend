module Api
  module V1
    class PromotionsController < BaseController
      def index
        promotions = Promotion.current.includes(:menu_item)
        render json: promotions.map { |p| PromotionSerializer.new(p).as_json }
      end
    end
  end
end