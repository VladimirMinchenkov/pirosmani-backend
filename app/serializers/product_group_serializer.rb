# app/serializers/product_group_serializer.rb
class ProductGroupSerializer
  def initialize(product_group)
    @product_group = product_group
  end

  def as_json(*)
    return nil if @product_group.nil?

    {
      id: @product_group.id,
      name: @product_group.name,
      slug: @product_group.slug
    }
  end
end
