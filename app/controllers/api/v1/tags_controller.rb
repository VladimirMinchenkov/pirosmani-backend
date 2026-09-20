module Api
  module V1
    class TagsController < BaseController
      def index
        tags = Tag.all.order(:name)
        render json: tags.map { |t| TagSerializer.new(t).as_json }
      end
    end
  end
end