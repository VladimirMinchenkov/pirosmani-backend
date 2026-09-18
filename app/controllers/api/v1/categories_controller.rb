module Api
  module V1
    class CategoriesController < BaseController
      def index
        categories = Category.order(:position)
        render json: categories.map { |c| CategorySerializer.new(c).as_json }
      end
    end
  end
end