module Admin
  module V1
    class TagsController < Admin::BaseController
      before_action :set_tag, only: [:show, :update, :destroy]

      def index
        tags = Tag.order(:name)
        render json: tags.map { |t| TagSerializer.new(t).as_json }
      end

      def show
        render json: TagSerializer.new(@tag).as_json
      end

      def create
        tag = Tag.new(tag_params)
        if tag.save
          render json: TagSerializer.new(tag).as_json, status: :created
        else
          render json: { errors: tag.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @tag.update(tag_params)
          render json: TagSerializer.new(@tag).as_json
        else
          render json: { errors: @tag.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @tag.destroy
        head :no_content
      end

      private

      def set_tag
        @tag = Tag.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Tag not found" }, status: :not_found
      end

      def tag_params
        params.require(:tag).permit(:name, :slug, :color, :emoji)
      end
    end
  end
end