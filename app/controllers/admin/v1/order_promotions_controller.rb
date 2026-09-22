module Admin
  module V1
    class OrderPromotionsController < Admin::BaseController
      before_action :set_order_promotion, only: [:show, :update, :destroy]

      def index
        promotions = OrderPromotion.order(created_at: :desc)
        render json: promotions.map { |op| OrderPromotionSerializer.new(op).as_json }
      end

      def show
        render json: OrderPromotionSerializer.new(@order_promotion).as_json
      end

      def create
        promotion = OrderPromotion.new(order_promotion_params)
        if promotion.save
          render json: OrderPromotionSerializer.new(promotion).as_json, status: :created
        else
          render json: { errors: promotion.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @order_promotion.update(order_promotion_params)
          render json: OrderPromotionSerializer.new(@order_promotion).as_json
        else
          render json: { errors: @order_promotion.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @order_promotion.destroy
        head :no_content
      end

      private

      def set_order_promotion
        @order_promotion = OrderPromotion.find(params[:id])
      end

      def order_promotion_params
        params.require(:order_promotion).permit(:min_amount, :discount_type, :discount_value, :starts_at, :ends_at, :active)
      end
    end
  end
end