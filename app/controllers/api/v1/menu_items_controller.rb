module Api
  module V1
    class MenuItemsController < BaseController
      INCLUDES = [:category, :tags, :menu_item_group, { addon_groups: :addons }].freeze

      def index
        menu_items = MenuItem.where(available: true).includes(INCLUDES).order(:position)
        render json: menu_items.map { |item| MenuItemSerializer.new(item).as_json }
      end

      def show
        menu_item = MenuItem.includes(INCLUDES).find(params[:id])
        render json: MenuItemSerializer.new(menu_item).as_json
      end
    end
  end
end
