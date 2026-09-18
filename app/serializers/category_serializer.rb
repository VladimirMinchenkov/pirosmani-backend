# app/serializers/category_serializer.rb
class CategorySerializer
  def initialize(category)
    @category = category
  end

  def as_json(*)
    return nil if @category.nil?

    {
      id: @category.id,
      name: @category.name,
      icon: @category.icon,
      position: @category.position
    }
  end
end
