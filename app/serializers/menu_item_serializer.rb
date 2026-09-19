# app/serializers/menu_item_serializer.rb
class MenuItemSerializer
  def initialize(menu_item)
    @menu_item = menu_item
  end

  def as_json(*)
    {
      id: @menu_item.id,
      name: @menu_item.name,
      description: @menu_item.description,
      price: @menu_item.price.to_f,
      image_url: @menu_item.image_url,
      available: @menu_item.available,
      weight_label: @menu_item.weight_label,
      calories: @menu_item.calories,
      allergens: @menu_item.allergens,
      sku: @menu_item.sku,
      position: @menu_item.position,
      category: CategorySerializer.new(@menu_item.category).as_json,
      tags: @menu_item.tags.map { |tag| TagSerializer.new(tag).as_json },
      menu_item_group: MenuItemGroupSerializer.new(@menu_item.menu_item_group).as_json,
      addon_groups: @menu_item.addon_groups.map { |group| AddonGroupSerializer.new(group).as_json }
    }
  end
end
