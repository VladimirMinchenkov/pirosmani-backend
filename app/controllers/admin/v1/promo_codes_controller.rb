module Admin
  module V1
    class PromoCodesController < Admin::BaseController
      before_action :set_promo_code, only: [:show, :update, :destroy]

      def index
        promo_codes = PromoCode.order(created_at: :desc)
        render json: promo_codes.map { |pc| PromoCodeSerializer.new(pc).as_json }
      end

      def show
        render json: PromoCodeSerializer.new(@promo_code).as_json
      end

      def create
        promo_code = PromoCode.new(promo_code_params)
        if promo_code.save
          render json: PromoCodeSerializer.new(promo_code).as_json, status: :created
        else
          render json: { errors: promo_code.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @promo_code.update(promo_code_params)
          render json: PromoCodeSerializer.new(@promo_code).as_json
        else
          render json: { errors: @promo_code.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @promo_code.destroy
        head :no_content
      end

      private

      def set_promo_code
        @promo_code = PromoCode.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Promo code not found" }, status: :not_found
      end

      def promo_code_params
        params.require(:promo_code).permit(
          :code, :discount_type, :discount_value, :min_order_price,
          :active, :active_from, :active_until, :usage_limit
        )
      end
    end
  end
end