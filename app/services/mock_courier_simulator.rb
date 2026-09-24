# app/services/mock_courier_simulator.rb
# Чистые функции-симуляторы курьера для yandex_courier_mode == 'mock'.
# Никаких сетевых запросов, никакого хранения состояния — всё считается
# по времени, прошедшему с claim_requested_at. Это позволяет полностью
# разработать и протестировать UI (админка + клиент) без реальных
# credentials от Яндекс.Доставки.
class MockCourierSimulator
  DEFAULT_ETA_MINUTES = 30.0
  # Курьер "выезжает" от кафе только после этой отметки (до этого он "ищется"/"у кафе")
  MOVE_START_MINUTES = 5.0

  STATUSES = [
    { key: "new", label: "Заявка создана", until_min: 1.0 },
    { key: "performer_lookup", label: "Ищем курьера", until_min: 3.0 },
    { key: "performer_found", label: "Курьер назначен", until_min: MOVE_START_MINUTES },
    { key: "pickup_arrived", label: "Курьер у кафе", until_min: MOVE_START_MINUTES + 1.0 },
    { key: "delivering", label: "Курьер в пути", until_min: DEFAULT_ETA_MINUTES - 1.0 },
    { key: "delivered", label: "Доставлено", until_min: Float::INFINITY }
  ].freeze

  COURIER_NAMES = ["Алексей К.", "Дмитрий В.", "Сергей П.", "Николай Т.", "Игорь М."].freeze
  VEHICLES = ["Renault Logan · А 123 БВ 7", "Lada Vesta · В 456 ГД 7", "Chevrolet Aveo · С 789 ЕЖ 7"].freeze

  class << self
    # Возвращает { key:, label: } для текущего момента симуляции
    def status_for(elapsed_minutes)
      STATUSES.find { |s| elapsed_minutes < s[:until_min] } || STATUSES.last
    end

    # from/to: [lat, lng]. Возвращает [lat, lng] курьера в текущий момент.
    def position_for(elapsed_minutes, from:, to:, eta_minutes: DEFAULT_ETA_MINUTES)
      fraction =
        if elapsed_minutes <= MOVE_START_MINUTES
          0.0
        elsif eta_minutes <= MOVE_START_MINUTES
          1.0
        else
          [(elapsed_minutes - MOVE_START_MINUTES) / (eta_minutes - MOVE_START_MINUTES), 1.0].min
        end

      lat = from[0] + (to[0] - from[0]) * fraction
      lng = from[1] + (to[1] - from[1]) * fraction
      [lat, lng]
    end

    def eta_remaining_minutes(elapsed_minutes, eta_minutes: DEFAULT_ETA_MINUTES)
      [(eta_minutes - elapsed_minutes).ceil, 0].max
    end

    # Детерминированный "случайный" курьер по seed (например, order.id),
    # чтобы один и тот же заказ всегда получал того же курьера при пересчёте.
    def generate_courier_snapshot(seed)
      rng = Random.new(seed.to_i)
      {
        name: COURIER_NAMES[rng.rand(COURIER_NAMES.size)],
        vehicle: VEHICLES[rng.rand(VEHICLES.size)],
        phone_masked: format("+375 29 %03d-%02d-%02d", rng.rand(1000), rng.rand(100), rng.rand(100))
      }
    end
  end
end
