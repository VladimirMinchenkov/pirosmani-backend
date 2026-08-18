module Api
  module V1
    class MenuItemsController < BaseController
      def index
        menu_items = MenuItem.where(available: true)
        render json: menu_items
      end

      def show
        menu_item = MenuItem.find(params[:id])
        render json: menu_item
      end
    end
  end
end
