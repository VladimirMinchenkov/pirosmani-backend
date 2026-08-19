## Удаляем старые тестовые зоны, чтобы не дублировать
DeliveryZone.destroy_all

# Полигон: [lng, lat] — обязательно замкнут (первая точка в конце)
# Это прямоугольник вокруг центра Геленджика
coordinates = [
  [38.0500, 44.5600],
  [38.0700, 44.5600],
  [38.0700, 44.5800],
  [38.0500, 44.5800],
  [38.0500, 44.5600]  # замыкаем полигон
]

DeliveryZone.create!(
  name: 'Брест центр',
  active: true,
  coordinates: coordinates
)

AppSetting.find_or_create_by(key: 'delivery_mode') do |s|
  s.value = 'yandex' # или 'internal'
end

