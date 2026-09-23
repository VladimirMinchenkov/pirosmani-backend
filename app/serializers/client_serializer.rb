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
      created_at: @client.created_at.iso8601,
      orders_count: @client.orders.size,
      has_active_order: @client.orders.any? { |o| %w[pending confirmed cooking delivering].include?(o.status) },
      last_order_id: @client.orders.max_by(&:created_at)&.id
    }
  end
end
