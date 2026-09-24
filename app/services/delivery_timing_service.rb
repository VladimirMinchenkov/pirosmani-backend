# app/services/delivery_timing_service.rb
# Чистый калькулятор тайминга "когда начинать готовку" / "когда вызывать курьера"
# для предзаказов и ASAP-заказов на доставку — с учётом РЕАЛЬНЫХ часов работы
# кафе (WorkingHoursService), а не только средних длительностей.
#
# Ключевая идея №1: готовка (P) и подъезд курьера (C) идут ПАРАЛЛЕЛЬНО — курьера
# вызываем не в момент старта готовки, а через (P − C) минут после него, чтобы
# он приехал на кафе ровно к готовности еды (а не раньше и не позже).
#
# Ключевая идея №2: любой предзаказ обязан укладываться в окно работы кафе —
# нельзя ни начать готовить до открытия, ни доставить/выдать после закрытия.
# Если сегодняшнее окно уже не позволяет — ищем ближайший подходящий момент на
# следующих днях (максимум MAX_DAYS_LOOKAHEAD дней вперёд).
#
# Ключевая идея №3: у кухни есть настраиваемый кутофф приёма заказов
# (AppSetting cafe_order_stop_minutes — например, кухня не берёт новые заказы
# позже, чем за 30 мин до закрытия). Этот кутофф — не просто "не принимать
# ASAP-заказы", а ограничение на момент СТАРТА готовки в принципе, поэтому он
# также ограничивает допустимое время предзаказа (см. latest_scheduled_at).
#
# См. plans/scheduled-delivery-courier-timing.md для диаграмм и обоснования.
class DeliveryTimingService
  MAX_DAYS_LOOKAHEAD = 7

  class << self
    # Минимальное время от "сейчас" до готовности блюда+доставки — используется
    # и для ASAP, и как компонент валидации предзаказов
    def min_lead_minutes(travel_minutes: AppSettingsService.avg_travel_minutes)
      max_prep_or_courier_minutes + travel_minutes + AppSettingsService.delivery_buffer_minutes
    end

    # Минимальное время до готовности с учётом типа заказа (доставка/самовывоз)
    def lead_minutes_for(order_type:, travel_minutes: AppSettingsService.avg_travel_minutes)
      order_type_delivery?(order_type) ? min_lead_minutes(travel_minutes: travel_minutes) : pickup_lead_minutes
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
    # к задержкам кухни.
    def claim_planned_at(cooking_started_at:)
      cooking_started_at + claim_delay_minutes.minutes
    end

    # Границы допустимого времени доставки/выдачи для конкретного дня.
    # Возвращает nil, если:
    #   - кафе в этот день не работает вообще, ИЛИ
    #   - рабочее окно этого дня физически слишком короткое, чтобы вместить
    #     минимальное время готовки+доставки (earliest > latest)
    # from — момент, раньше которого нельзя начать готовить СЕГОДНЯ (для
    # текущего дня это max(open_at, from); для будущих дней — просто open_at).
    def day_bounds(date:, order_type:, travel_minutes: AppSettingsService.avg_travel_minutes, from: Time.current)
      hours = WorkingHoursService.hours_for(date)
      return nil unless hours

      latest = latest_scheduled_at(date: date, order_type: order_type, travel_minutes: travel_minutes)
      return nil unless latest

      open_at = WorkingHoursService.time_on(date, hours["open"])
      lead = lead_minutes_for(order_type: order_type, travel_minutes: travel_minutes)
      kitchen_start_floor = date == from.to_date ? [open_at, from].max : open_at
      earliest = kitchen_start_floor + lead.minutes

      return nil if earliest > latest

      { earliest: earliest, latest: latest }
    end

    # Самый ранний момент, когда заказ данного типа реально может быть готов
    # и доставлен/выдан, считая от `from` — учитывает и минимальное время
    # готовки+доставки, и реальные часы работы кафе (в т.ч. на будущие дни,
    # если сегодня уже не укладывается). Возвращает nil, если за
    # MAX_DAYS_LOOKAHEAD дней не нашлось подходящего дня (не должно случаться
    # в норме — означало бы, что кафе закрыто дольше недели).
    def earliest_available_at(order_type:, travel_minutes: AppSettingsService.avg_travel_minutes, from: Time.current)
      (0..MAX_DAYS_LOOKAHEAD).each do |day_offset|
        date = (from + day_offset.days).to_date
        bounds = day_bounds(date: date, order_type: order_type, travel_minutes: travel_minutes, from: from)
        return bounds[:earliest] if bounds
      end

      nil
    end

    # Самое позднее время доставки/выдачи в указанный день — минимум из двух
    # физических ограничений:
    #   1) курьер должен успеть доехать до клиента до закрытия кафе (для
    #      самовывоза — просто буфер до закрытия, чтобы гость успел забрать);
    #   2) кухня не может НАЧАТЬ готовку позже настроенного "стоп-времени
    #      приёма заказов" (close_at − cafe_order_stop_minutes) — того же
    #      кутоффа, что используется для ASAP через
    #      WorkingHoursService.accepting_orders?, но применённого к полной
    #      формуле готовка+доставка/выдача, а не только к моменту приёма.
    def latest_scheduled_at(date:, order_type:, travel_minutes: AppSettingsService.avg_travel_minutes)
      hours = WorkingHoursService.hours_for(date)
      return nil unless hours

      close_at = WorkingHoursService.time_on(date, hours["close"])
      buffer = AppSettingsService.delivery_buffer_minutes.minutes

      courier_arrival_limit =
        order_type_delivery?(order_type) ? close_at - travel_minutes.minutes - buffer : close_at - buffer

      stop_at = close_at - WorkingHoursService.order_stop_minutes.minutes
      kitchen_stop_limit = stop_at + AppSettingsService.avg_cooking_minutes.minutes +
        (order_type_delivery?(order_type) ? travel_minutes.minutes : 0) + buffer

      [courier_arrival_limit, kitchen_stop_limit].min
    end

    private

    def order_type_delivery?(order_type)
      order_type.to_s == "delivery"
    end

    def pickup_lead_minutes
      AppSettingsService.avg_cooking_minutes + AppSettingsService.delivery_buffer_minutes
    end

    def max_prep_or_courier_minutes
      [AppSettingsService.avg_cooking_minutes, AppSettingsService.avg_courier_arrival_minutes].max
    end
  end
end
