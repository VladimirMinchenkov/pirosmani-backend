class ComboSerializer
  def initialize(combo)
    @combo = combo
  end

  def as_json(*)
    {
      id: @combo.id,
      name: @combo.name,
      description: @combo.description,
      price: @combo.price.to_f,
      original_price: @combo.original_price.to_f,
      savings: @combo.savings.to_f,
      image_url: @combo.image_url,
      active: @combo.active,
      items: @combo.combo_items.map { |ci|
        {
          id: ci.id,
          menu_item_id: ci.menu_item_id,
          name: ci.menu_item.name,
          quantity: ci.quantity,
          unit_price: ci.menu_item.price.to_f
        }
      },
      created_at: @combo.created_at.iso8601
    }
  end
end