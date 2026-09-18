# app/serializers/client_address_serializer.rb
class ClientAddressSerializer
  def initialize(client_address)
    @client_address = client_address
  end

  def as_json(*)
    return nil if @client_address.nil?

    {
      id: @client_address.id,
      label: @client_address.label,
      emoji: @client_address.emoji,
      street: @client_address.street,
      entrance: @client_address.entrance,
      apt: @client_address.apt,
      floor: @client_address.floor,
      intercom: @client_address.intercom,
      lat: @client_address.lat&.to_f,
      lng: @client_address.lng&.to_f
    }
  end
end
