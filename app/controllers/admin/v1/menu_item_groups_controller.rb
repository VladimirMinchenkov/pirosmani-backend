module Admin
  module V1
    class MenuItemGroupsController < Admin::BaseController
      before_action :set_menu_item_group, only: [:show, :update, :destroy]

      def index
        menu_item_groups = MenuItemGroup.order(:name)
        render json: menu_item_groups.map { |pg| MenuItemGroupSerializer.new(pg).as_json }
      end

      def show
        render json: MenuItemGroupSerializer.new(@menu_item_group).as_json
      end

      def create
        menu_item_group = MenuItemGroup.new(menu_item_group_params)
        if menu_item_group.save
          render json: MenuItemGroupSerializer.new(menu_item_group).as_json, status: :created
        else
          render json: { errors: menu_item_group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @menu_item_group.update(menu_item_group_params)
          render json: MenuItemGroupSerializer.new(@menu_item_group).as_json
        else
          render json: { errors: @menu_item_group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @menu_item_group.destroy
        head :no_content
      end

      private

      def set_menu_item_group
        @menu_item_group = MenuItemGroup.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Product group not found" }, status: :not_found
      end

      def menu_item_group_params
        params.require(:menu_item_group).permit(:name, :slug)
      end
    end
  end
end