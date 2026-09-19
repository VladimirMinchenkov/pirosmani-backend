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

      # GET /admin/v1/categories/:id/content
      def content
        category = Category.find(params[:id])
        items = []

        category.menu_items.standalone.order(:position_in_category).each do |mi|
          items << { type: 'menu_item', id: mi.id, name: mi.name, price: mi.price, available: mi.available }
        end

        category.menu_item_groups.order(:position_in_category).each do |g|
          items << { type: 'menu_item_group', id: g.id, name: g.name, items_count: g.menu_items.count, available: g.available }
        end

        items.sort_by! { |i| i[:position_in_category] || 0 }

        render json: { category: CategorySerializer.new(category).as_json, content: items }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Category not found' }, status: :not_found
      end

      # PATCH /admin/v1/categories/:id/content/reorder
      def reorder
        category = Category.find(params[:id])
        items_data = params.require(:items)

        ActiveRecord::Base.transaction do
          # Сначала сбрасываем все позиции в отрицательные, чтобы избежать конфликтов
          category.menu_items.standalone.update_all(position_in_category: -1)
          category.menu_item_groups.update_all(position_in_category: -1)

          # Затем устанавливаем финальные позиции
          items_data.each do |item_data|
            case item_data[:type]
            when 'menu_item'
              category.menu_items.standalone.find(item_data[:id])
                      .update!(position_in_category: item_data[:position_in_category])
            when 'menu_item_group'
              category.menu_item_groups.find(item_data[:id])
                      .update!(position_in_category: item_data[:position_in_category])
            else
              raise ActiveRecord::RecordInvalid, "Unknown type: #{item_data[:type]}"
            end
          end
        end
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Category or item not found' }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_category
        @category = Category.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Category not found" }, status: :not_found
      end

      def category_params
        params.require(:category).permit(:name, :icon, :image_url, :position)
      end
    end
  end
end