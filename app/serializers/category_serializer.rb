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
      image_url: image_url(@category),
      position: @category.position
    }
  end

  private

  def image_url(record)
    if record.image.attached?
      Rails.application.routes.url_helpers.url_for(record.image)
    else
      record.image_url
    end
  rescue StandardError
    record.image_url
  end
end
