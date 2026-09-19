# app/serializers/menu_item_group_serializer.rb
class MenuItemGroupSerializer
  def initialize(menu_item_group)
    @menu_item_group = menu_item_group
  end

  def as_json(*)
    return nil if @menu_item_group.nil?

    {
      id: @menu_item_group.id,
      name: @menu_item_group.name,
      slug: @menu_item_group.slug,
      category_id: @menu_item_group.category_id,
      position_in_category: @menu_item_group.position_in_category,
      min_total_quantity: @menu_item_group.min_total_quantity,
      description: @menu_item_group.description,
      image_url: @menu_item_group.image_url,
      available: @menu_item_group.available
    }
  end
end
