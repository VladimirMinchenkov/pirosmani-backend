# app/serializers/cart_serializer.rb
class CartSerializer
  def initialize(cart)
    @cart = cart
  end

  def as_json(*)
    {
      id: @cart.id,
      session_id: @cart.session_id,
      status: @cart.status,
      cart_items: @cart.cart_items.includes(:menu_item, :cart_item_addons).map do |item|
        {
          id: item.id,
          menu_item_id: item.menu_item_id,
          name: item.menu_item.name,
          price: item.price.to_f,
          quantity: item.quantity,
          addons: item.cart_item_addons.map do |addon|
            {
              id: addon.id,
              addon_id: addon.addon_id,
              name: addon.addon_name,
              price: addon.addon_price.to_f,
              quantity: addon.quantity
            }
          end
        }
      end
    }
  end
end