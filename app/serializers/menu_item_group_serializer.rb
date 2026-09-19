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
      slug: @menu_item_group.slug
    }
  end
end
