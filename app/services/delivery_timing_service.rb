# app/services/delivery_timing_service.rb
# Чистый калькулятор тайминга "когда начинать готовку" / "когда вызывать курьера"
# для предзаказов и ASAP-заказов на доставку.
#
# Ключевая идея: готовка (P) и подъезд курьера (C) идут ПАРАЛЛЕЛЬНО — курьера
# вызываем не в момент старта готовки, а через (P − C) минут после него, чтобы
# он приехал на кафе ровно к готовности еды (а не раньше и не позже).
# Если C > P — курьер приезжает позже готовки еды, тогда вызываем его сразу
# (задержка 0), и узким местом становится подъезд курьера, а не готовка.
#
# См. plans/scheduled-delivery-courier-timing.md для диаграмм и обоснования.
class DeliveryTimingService
  class << self
    # Минимальное время от "сейчас" до готовности блюда+доставки (для ASAP
    # и для валидации минимального scheduled_at у предзаказов)
    # travel_minutes — по умолчанию средняя настройка, но лучше передавать
    # реальную оценку Yandex check-price для конкретного адреса
    def min_lead_minutes(travel_minutes: AppSettingsService.avg_travel_minutes)
      max_prep_or_courier_minutes + travel_minutes + AppSettingsService.delivery_buffer_minutes
    end

    # Плановое время начала готовки, посчитанное НАЗАД от желаемого времени
    # доставки (для предзаказов). target_delivery_at — это Order#scheduled_at.
    def cooking_start_planned_at(target_delivery_at:, travel_minutes: AppSettingsService.avg_travel_minutes)
      target_delivery_at -
        AppSettingsService.delivery_buffer_minutes.minutes -
        travel_minutes.minutes -
        AppSettingsService.avg_cooking_minutes.minutes
    end

    # Через сколько минут после ФАКТИЧЕСКОГО старта готовки нужно вызвать
    # курьера, чтобы он приехал на кафе ровно к готовности блюда
    def claim_delay_minutes
      [AppSettingsService.avg_cooking_minutes - AppSettingsService.avg_courier_arrival_minutes, 0].max
    end

    # Плановое время вызова курьера — считается от факта старта готовки
    # (cooking_started_at), а не от scheduled_at, чтобы система была устойчива
    # к задержкам кухни: если кухня начала готовить позже плана, вызов курьера
    # сдвинется вместе с ней (курьер всё равно приедет синхронно с готовностью еды)
    def claim_planned_at(cooking_started_at:)
      cooking_started_at + claim_delay_minutes.minutes
    end

    private

    def max_prep_or_courier_minutes
      [AppSettingsService.avg_cooking_minutes, AppSettingsService.avg_courier_arrival_minutes].max
    end
  end
end
