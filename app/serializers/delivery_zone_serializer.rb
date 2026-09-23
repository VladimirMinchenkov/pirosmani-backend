# app/serializers/delivery_zone_serializer.rb
class DeliveryZoneSerializer
  def initialize(delivery_zone)
    @delivery_zone = delivery_zone
  end

  def as_json(*)
    {
      id: @delivery_zone.id,
      name: @delivery_zone.name,
      active: @delivery_zone.active,
      price: @delivery_zone.price&.to_f,
      coordinates: @delivery_zone.coordinates
    }
  end
end