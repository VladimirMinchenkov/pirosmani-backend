module Admin
  module V1
    class PromotionsController < Admin::BaseController
      before_action :set_promotion, only: [:show, :update, :destroy]

      def index
        promotions = Promotion.includes(:menu_item).order(created_at: :desc)
        render json: promotions.map { |p| PromotionSerializer.new(p).as_json }
      end

      def show
        render json: PromotionSerializer.new(@promotion).as_json
      end

      def create
        promotion = Promotion.new(promotion_params)
        if promotion.save
          render json: PromotionSerializer.new(promotion).as_json, status: :created
        else
          render json: { errors: promotion.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @promotion.update(promotion_params)
          render json: PromotionSerializer.new(@promotion).as_json
        else
          render json: { errors: @promotion.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @promotion.destroy
        head :no_content
      end

      private

      def set_promotion
        @promotion = Promotion.find(params[:id])
      end

      def promotion_params
        params.require(:promotion).permit(:menu_item_id, :discount_type, :discount_value, :starts_at, :ends_at, :active)
      end
    end
  end
end