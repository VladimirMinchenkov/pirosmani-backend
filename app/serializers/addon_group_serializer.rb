# app/serializers/addon_group_serializer.rb
class AddonGroupSerializer
  def initialize(addon_group)
    @addon_group = addon_group
  end

  def as_json(*)
    {
      id: @addon_group.id,
      name: @addon_group.name,
      min_selection: @addon_group.min_selection,
      max_selection: @addon_group.max_selection,
      required: @addon_group.required,
      addons: @addon_group.addons.map { |addon| AddonSerializer.new(addon).as_json }
    }
  end
end
