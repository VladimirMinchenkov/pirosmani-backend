# app/serializers/order_serializer.rb
class OrderSerializer
  def initialize(order)
    @order = order
  end

  def as_json(*)
    {
      id: @order.id,
      status: @order.status,
      order_type: @order.order_type,
      address: @order.address,
      client_address: ClientAddressSerializer.new(@order.client_address).as_json,
      scheduled_at: @order.scheduled_at,
      total_price: @order.total_price.to_f,
      delivery_price: @order.delivery_price.to_f,
      created_at: @order.created_at,
      order_items: @order.order_items.map { |oi| OrderItemSerializer.new(oi).as_json }
    }
  end
end
