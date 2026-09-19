module Admin
  module V1
    class MenuItemGroupsController < Admin::BaseController
      before_action :set_menu_item_group, only: [:show, :update, :destroy]

      def index
        groups = MenuItemGroup.includes(:category).order(:name)
        render json: groups.map { |g| MenuItemGroupSerializer.new(g).as_json }
      end

      def show
        render json: MenuItemGroupSerializer.new(@menu_item_group).as_json
      end

      def create
        group = MenuItemGroup.new(menu_item_group_params)
        group.position_in_category = next_position(group.category_id) if group.category_id
        if group.save
          render json: MenuItemGroupSerializer.new(group).as_json, status: :created
        else
          render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
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
        if @menu_item_group.menu_items.any?
          render json: { error: 'Cannot delete group with items. Remove items first.' }, status: :unprocessable_entity
        else
          @menu_item_group.destroy
          head :no_content
        end
      end

      # POST /admin/v1/menu_item_groups/:id/menu_items
      def create_item
        group = MenuItemGroup.find(params[:id])
        item = group.menu_items.new(menu_item_params.merge(category_id: group.category_id))
        item.position_in_group = next_group_position(group.id)
        if item.save
          render json: MenuItemSerializer.new(item).as_json, status: :created
        else
          render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Group not found' }, status: :not_found
      end

      # PATCH /admin/v1/menu_item_groups/:id/items/reorder
      def reorder_items
        group = MenuItemGroup.find(params[:id])
        items_data = params.require(:items)
        MenuItem.transaction do
          items_data.each do |item_data|
            group.menu_items.find(item_data[:id]).update!(position_in_group: item_data[:position_in_group])
          end
        end
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Group or item not found' }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_menu_item_group
        @menu_item_group = MenuItemGroup.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Menu item group not found' }, status: :not_found
      end

      def menu_item_group_params
        params.require(:menu_item_group).permit(
          :name, :slug, :category_id, :position_in_category,
          :min_total_quantity, :description, :image_url, :available
        )
      end

      def menu_item_params
        params.require(:menu_item).permit(
          :name, :description, :price, :image_url, :available,
          :weight_label, :calories, :sku, :display_mode,
          allergens: []
        )
      end

      def next_position(category_id)
        max_pos = MenuItemGroup.where(category_id: category_id).maximum(:position_in_category) || -1
        max_pos + 1
      end

      def next_group_position(group_id)
        max_pos = MenuItem.where(menu_item_group_id: group_id).maximum(:position_in_group) || -1
        max_pos + 1
      end
    end
  end
end