# app/serializers/addon_serializer.rb
class AddonSerializer
  def initialize(addon)
    @addon = addon
  end

  def as_json(*)
    {
      id: @addon.id,
      name: @addon.name,
      price: @addon.price.to_f
    }
  end
end
