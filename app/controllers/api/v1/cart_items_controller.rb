module Api
  module V1
    class CartItemsController < BaseController
      before_action :find_or_create_cart
      before_action :set_cart_item, only: [:update, :destroy]

      def create
        menu_item = MenuItem.find_by!(id: params[:menu_item_id], available: true)
        quantity = (params[:quantity] || 1).to_i

        cart_item = @cart.cart_items.find_or_initialize_by(menu_item: menu_item)
        is_new = cart_item.new_record?

        if is_new
          cart_item.quantity = quantity
          cart_item.price = menu_item.price
        else
          cart_item.quantity += quantity
        end

        ActiveRecord::Base.transaction do
          cart_item.save!
          sync_addons(cart_item) if params[:addon_ids].present?
        end

        render json: CartSerializer.new(@cart.reload).as_json, status: (is_new ? :created : :ok)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Menu item not found or unavailable" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        quantity = params[:quantity].to_i

        if quantity <= 0
          @cart_item.destroy!
          render json: CartSerializer.new(@cart.reload).as_json
          return
        end

        ActiveRecord::Base.transaction do
          @cart_item.update!(quantity: quantity)
          sync_addons(@cart_item) if params[:addon_ids].present?
        end

        render json: CartSerializer.new(@cart.reload).as_json
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def destroy
        @cart_item.destroy!
        render json: CartSerializer.new(@cart.reload).as_json
      end

      private

      def find_or_create_cart
        if current_client.present?
          @cart = Cart.find_or_create_by!(client: current_client, status: :active)
        else
          session_id = request.headers['X-Client-Session-Id']
          if session_id.blank?
            render json: { error: "Session ID required for guest users" }, status: :bad_request
            return
          end
          @cart = Cart.find_or_create_by!(session_id: session_id, status: :active)
        end
      end

      def set_cart_item
        @cart_item = @cart.cart_items.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Cart item not found" }, status: :not_found
      end

      def sync_addons(cart_item)
        addon_ids = Array(params[:addon_ids]).map(&:to_i)
        existing_addon_ids = cart_item.cart_item_addons.pluck(:addon_id).compact

        # Remove addons not in the new list
        to_remove = existing_addon_ids - addon_ids
        cart_item.cart_item_addons.where(addon_id: to_remove).destroy_all if to_remove.any?

        # Add new addons
        to_add = addon_ids - existing_addon_ids
        to_add.each do |addon_id|
          addon = Addon.find(addon_id)
          cart_item.cart_item_addons.create!(addon: addon)
        end
      end
    end
  end
end
