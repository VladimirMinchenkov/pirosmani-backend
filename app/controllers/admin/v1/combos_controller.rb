module Admin
  module V1
    class CombosController < Admin::BaseController
      before_action :set_combo, only: [:show, :update, :destroy]

      def index
        combos = Combo.includes(:combo_items).order(created_at: :desc)
        render json: combos.map { |c| ComboSerializer.new(c).as_json }
      end

      def show
        render json: ComboSerializer.new(@combo).as_json
      end

      def create
        combo = Combo.new(combo_params)
        if combo.save
          render json: ComboSerializer.new(combo).as_json, status: :created
        else
          render json: { errors: combo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @combo.update(combo_params)
          render json: ComboSerializer.new(@combo).as_json
        else
          render json: { errors: @combo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @combo.destroy
        head :no_content
      end

      private

      def set_combo
        @combo = Combo.find(params[:id])
      end

      def combo_params
        params.require(:combo).permit(:name, :description, :price, :image_url, :active,
          combo_items_attributes: [:id, :menu_item_id, :quantity, :_destroy])
      end
    end
  end
end