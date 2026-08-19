# app/models/delivery_zone.rb
class DeliveryZone < ApplicationRecord
  has_many :orders

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # coordinates - это jsonb колонка с массивом [[lng, lat], [lng, lat], ...]
  validates :coordinates, presence: true, length: { minimum: 4 } # Минимум 3 точки + повтор первой

  scope :active, -> { where(active: true) }

  # Проверка: входит ли точка (lat, lng) в полигон?
  # ВАЖНО: В базу мы кладем [lng, lat]. Здесь мы принимаем (lat, lng).
  def contains_point?(lat, lng)
    return false unless coordinates.is_a?(Array) && coordinates.size >= 4

    # Ray Casting Algorithm
    inside = false
    j = coordinates.size - 1

    coordinates.each_with_index do |current, i|
      # current это [x, y] -> [lng, lat]
      x1, y1 = current
      x2, y2 = coordinates[j]

      # Проверка пересечения луча, идущего вправо от точки, с ребром полигона
      # Условие 1: точка лежит строго между широтами вершин ребра
      # Условие 2: долгота точки меньше точки пересечения ребра с горизонтальной линией
      if ((y1 > lat) != (y2 > lat)) &&
         (lng < (x2 - x1) * (lat - y1) / (y2 - y1).to_f + x1)
        inside = !inside
      end

      j = i
    end

    inside
  end
end
