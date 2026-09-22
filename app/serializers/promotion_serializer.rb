class PromotionSerializer
  def initialize(promotion)
    @promotion = promotion
  end

  def as_json(*)
    {
      id: @promotion.id,
      menu_item_id: @promotion.menu_item_id,
      menu_item_name: @promotion.menu_item.name,
      discount_type: @promotion.discount_type,
      discount_value: @promotion.discount_value.to_f,
      starts_at: @promotion.starts_at&.iso8601,
      ends_at: @promotion.ends_at&.iso8601,
      active: @promotion.active,
      created_at: @promotion.created_at.iso8601
    }
  end
end