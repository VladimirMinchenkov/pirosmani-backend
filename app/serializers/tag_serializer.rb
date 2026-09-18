# app/serializers/tag_serializer.rb
class TagSerializer
  def initialize(tag)
    @tag = tag
  end

  def as_json(*)
    {
      id: @tag.id,
      name: @tag.name,
      slug: @tag.slug
    }
  end
end
