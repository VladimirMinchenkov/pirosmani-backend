class OrderPromotionSerializer
  def initialize(order_promotion)
    @order_promotion = order_promotion
  end

  def as_json(*)
    {
      id: @order_promotion.id,
      min_amount: @order_promotion.min_amount.to_f,
      discount_type: @order_promotion.discount_type,
      discount_value: @order_promotion.discount_value.to_f,
      starts_at: @order_promotion.starts_at&.iso8601,
      ends_at: @order_promotion.ends_at&.iso8601,
      active: @order_promotion.active,
      created_at: @order_promotion.created_at.iso8601
    }
  end
end