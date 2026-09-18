# app/serializers/order_item_serializer.rb
class OrderItemSerializer
  def initialize(order_item)
    @order_item = order_item
  end

  def as_json(*)
    {
      id: @order_item.id,
      menu_item_id: @order_item.menu_item_id,
      name: @order_item.menu_item.name,
      quantity: @order_item.quantity,
      price: @order_item.price.to_f,
      addons: @order_item.order_item_addons.map do |addon|
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
end
