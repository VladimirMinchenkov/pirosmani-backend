module Admin
  module V1
    class ProductGroupsController < Admin::BaseController
      before_action :set_product_group, only: [:show, :update, :destroy]

      def index
        product_groups = ProductGroup.order(:name)
        render json: product_groups.map { |pg| ProductGroupSerializer.new(pg).as_json }
      end

      def show
        render json: ProductGroupSerializer.new(@product_group).as_json
      end

      def create
        product_group = ProductGroup.new(product_group_params)
        if product_group.save
          render json: ProductGroupSerializer.new(product_group).as_json, status: :created
        else
          render json: { errors: product_group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @product_group.update(product_group_params)
          render json: ProductGroupSerializer.new(@product_group).as_json
        else
          render json: { errors: @product_group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @product_group.destroy
        head :no_content
      end

      private

      def set_product_group
        @product_group = ProductGroup.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Product group not found" }, status: :not_found
      end

      def product_group_params
        params.require(:product_group).permit(:name, :slug)
      end
    end
  end
end