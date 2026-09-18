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
      image_url: @category.image_url,
      position: @category.position
    }
  end
end
