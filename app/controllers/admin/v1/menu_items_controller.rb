module Admin
  module V1
    class MenuItemsController < Admin::BaseController
      INCLUDES = [:category, :tags, :menu_item_group, { addon_groups: :addons }].freeze

      before_action :set_menu_item, only: [:show, :update, :destroy]

      def index
        menu_items = MenuItem.includes(INCLUDES).order(:position)
        render json: menu_items.map { |item| MenuItemSerializer.new(item).as_json }
      end

      def show
        render json: MenuItemSerializer.new(@menu_item).as_json
      end

      def create
        menu_item = MenuItem.new(menu_item_params)
        ActiveRecord::Base.transaction do
          menu_item.save!
          assign_tags(menu_item)
          assign_addon_groups(menu_item)
        end
        render json: MenuItemSerializer.new(menu_item.reload).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        ActiveRecord::Base.transaction do
          @menu_item.update!(menu_item_params)
          assign_tags(@menu_item)
          assign_addon_groups(@menu_item)
        end
        render json: MenuItemSerializer.new(@menu_item.reload).as_json
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def destroy
        @menu_item.destroy
        head :no_content
      end

      private

      def set_menu_item
        @menu_item = MenuItem.includes(INCLUDES).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Menu item not found" }, status: :not_found
      end

      def menu_item_params
        params.require(:menu_item).permit(
          :name, :description, :price, :image_url, :available,
          :category_id, :menu_item_group_id,
          :position_in_category, :position_in_group,
          :weight_label, :calories, :sku, :position,
          allergens: [], tag_ids: [], addon_group_ids: []
        )
      end

      def assign_tags(menu_item)
        return unless params[:menu_item][:tag_ids]

        menu_item.tags = Tag.where(id: params[:menu_item][:tag_ids])
      end

      def assign_addon_groups(menu_item)
        return unless params[:menu_item][:addon_group_ids]

        menu_item.addon_groups = AddonGroup.where(id: params[:menu_item][:addon_group_ids])
      end
    end
  end
end
