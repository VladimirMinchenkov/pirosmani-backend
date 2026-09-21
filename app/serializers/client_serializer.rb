# app/serializers/client_serializer.rb
class ClientSerializer
  def initialize(client)
    @client = client
  end

  def as_json(*)
    {
      id: @client.id,
      phone: @client.phone,
      name: @client.name,
      bonus_points: @client.bonus_points,
      created_at: @client.created_at&.iso8601,
      orders_count: @client.orders.size,
      has_active_order: @client.orders.where(status: %w[pending confirmed cooking delivering]).exists?,
      last_order_id: @client.orders.order(created_at: :desc).pick(:id)
    }
  end
end