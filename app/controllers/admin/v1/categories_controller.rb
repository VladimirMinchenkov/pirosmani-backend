module Admin
  module V1
    class CategoriesController < Admin::BaseController
      before_action :set_category, only: [:show, :update, :destroy]

      def index
        categories = Category.order(:position)
        render json: categories.map { |c| CategorySerializer.new(c).as_json }
      end

      def show
        render json: CategorySerializer.new(@category).as_json
      end

      def create
        category = Category.new(category_params)
        if category.save
          render json: CategorySerializer.new(category).as_json, status: :created
        else
          render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @category.update(category_params)
          render json: CategorySerializer.new(@category).as_json
        else
          render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @category.destroy
        head :no_content
      end

      private

      def set_category
        @category = Category.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Category not found" }, status: :not_found
      end

      def category_params
        params.require(:category).permit(:name, :icon, :position)
      end
    end
  end
end