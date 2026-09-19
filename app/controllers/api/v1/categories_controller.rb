module Api
  module V1
    class CategoriesController < BaseController
      def index
        categories = Category.order(:position)
        render json: categories.map { |c| CategorySerializer.new(c).as_json }
      end

      def menu
        category = Category.find(params[:id])

        standalone_items = category.menu_items
          .standalone
          .where(available: true)
          .includes(:tags, :addon_groups)
          .order(:position_in_category)

        groups = category.menu_item_groups
          .where(available: true)
          .includes(menu_items: [:tags, :addon_groups])
          .order(:position_in_category)

        items = merge_and_sort(standalone_items, groups)

        render json: {
          category: CategorySerializer.new(category).as_json,
          items: items.map { |item| serialize_item(item) }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Category not found' }, status: :not_found
      end

      private

      def merge_and_sort(standalone_items, groups)
        result = []
        standalone_items.each { |mi| result << { type: :menu_item, record: mi, position: mi.position_in_category || 0 } }
        groups.each { |g| result << { type: :menu_item_group, record: g, position: g.position_in_category } }
        result.sort_by { |r| r[:position] }
      end

      def serialize_item(item)
        if item[:type] == :menu_item
          mi = item[:record]
          {
            type: 'menu_item',
            id: mi.id,
            name: mi.name,
            description: mi.description,
            price: mi.price.to_f,
            image_url: mi.image_url,
            available: mi.available,
            weight_label: mi.weight_label,
            calories: mi.calories,
            allergens: mi.allergens,
            sku: mi.sku,
            display_mode: mi.display_mode,
            position_in_category: mi.position_in_category,
            tags: mi.tags.map { |t| TagSerializer.new(t).as_json },
            addon_groups: mi.addon_groups.map { |ag| AddonGroupSerializer.new(ag).as_json }
          }
        else
          group = item[:record]
          {
            type: 'menu_item_group',
            id: group.id,
            name: group.name,
            description: group.description,
            image_url: group.image_url,
            min_total_quantity: group.min_total_quantity,
            position_in_category: group.position_in_category,
            items: group.menu_items.select(&:available?).map do |mi|
              {
                id: mi.id,
                name: mi.name,
                description: mi.description,
                price: mi.price.to_f,
                image_url: mi.image_url,
                available: mi.available,
                weight_label: mi.weight_label,
                calories: mi.calories,
                allergens: mi.allergens,
                sku: mi.sku,
                position_in_group: mi.position_in_group,
                tags: mi.tags.map { |t| TagSerializer.new(t).as_json },
                addon_groups: mi.addon_groups.map { |ag| AddonGroupSerializer.new(ag).as_json }
              }
            end
          }
        end
      end
    end
  end
end