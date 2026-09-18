# app/serializers/promo_code_serializer.rb
class PromoCodeSerializer
  def initialize(promo_code)
    @promo_code = promo_code
  end

  def as_json(*)
    {
      id: @promo_code.id,
      code: @promo_code.code,
      discount_type: @promo_code.discount_type,
      discount_value: @promo_code.discount_value.to_f,
      min_order_price: @promo_code.min_order_price&.to_f,
      active: @promo_code.active,
      active_from: @promo_code.active_from,
      active_until: @promo_code.active_until,
      usage_limit: @promo_code.usage_limit,
      usage_count: @promo_code.usage_count,
      created_at: @promo_code.created_at,
      updated_at: @promo_code.updated_at
    }
  end
end