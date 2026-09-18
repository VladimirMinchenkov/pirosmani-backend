module Api
  module V1
    class CartsController < BaseController
      def show
        cart = find_or_create_cart
        render json: CartSerializer.new(cart).as_json
      end

      def update
        cart = find_or_create_cart
        # Массовое обновление корзины (замена всех позиций)
        # Ожидается: { cart_items: [{ menu_item_id:, quantity:, addon_ids: [] }, ...] }
        if params[:cart_items].present?
          ActiveRecord::Base.transaction do
            cart.cart_items.destroy_all

            params[:cart_items].each do |item_params|
              menu_item = MenuItem.find_by!(id: item_params[:menu_item_id], available: true)
              cart_item = cart.cart_items.create!(
                menu_item: menu_item,
                quantity: item_params[:quantity].to_i,
                price: menu_item.price
              )

              Array(item_params[:addon_ids]).each do |addon_id|
                addon = Addon.find(addon_id)
                cart_item.cart_item_addons.create!(addon: addon)
              end
            end
          end
        end

        render json: CartSerializer.new(cart.reload).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Menu item or addon not found" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def destroy
        cart = find_or_create_cart
        cart.cart_items.destroy_all
        render json: CartSerializer.new(cart.reload).as_json
      end

      private

      def find_or_create_cart
        if current_client.present?
          cart = Cart.find_or_create_by!(client: current_client, status: :active)
        else
          session_id = request.headers['X-Client-Session-Id']
          if session_id.blank?
            cart = Cart.create!(session_id: SecureRandom.hex(8), status: :active)
            # Возвращаем session_id через заголовок или тело ответа — handled in show
            return cart
          end
          cart = Cart.find_or_create_by!(session_id: session_id, status: :active)
        end
        cart
      end
    end
  end
end
