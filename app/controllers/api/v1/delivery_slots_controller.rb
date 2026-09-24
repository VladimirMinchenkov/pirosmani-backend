# app/controllers/api/v1/delivery_slots_controller.rb
# Единый источник истины для доступных слотов предзаказа — вместо того, чтобы
# фронтенд дублировал хардкодом часы работы (11:00–22:30) и математику
# готовка+доставка, он запрашивает у backend реально доступные дни/слоты,
# посчитанные через WorkingHoursService + DeliveryTimingService.
# См. plans/scheduled-delivery-courier-timing.md
module Api
  module V1
    class DeliverySlotsController < BaseController
      DAYS_AHEAD = 3
      SLOT_STEP_MINUTES = 30

      def show
        order_type = %w[delivery pickup].include?(params[:order_type]) ? params[:order_type] : "delivery"
        travel_minutes = params[:travel_minutes].presence&.to_f || AppSettingsService.avg_travel_minutes

        render json: {
          accepting_asap: WorkingHoursService.accepting_orders?,
          asap_status_text: WorkingHoursService.status_text,
          min_lead_minutes: DeliveryTimingService.lead_minutes_for(order_type: order_type, travel_minutes: travel_minutes).ceil,
          days: build_days(order_type, travel_minutes)
        }
      end

      private

      def build_days(order_type, travel_minutes)
        (0...DAYS_AHEAD).map do |offset|
          date = (Time.current + offset.days).to_date
          hours = WorkingHoursService.hours_for(date)
          # "Живой" замер от Yandex check-price (передан фронтендом как
          # travel_minutes) отражает трафик ПРЯМО СЕЙЧАС — релевантен только
          # для сегодняшнего дня. Для завтра/послезавтра реальный трафик на
          # момент доставки неизвестен — используем усреднённую настройку,
          # иначе, например, дневной затор "сейчас" мог бы неверно сузить/
          # расширить слоты на завтрашний вечер.
          effective_travel_minutes = offset.zero? ? travel_minutes : AppSettingsService.avg_travel_minutes
          bounds = DeliveryTimingService.day_bounds(date: date, order_type: order_type, travel_minutes: effective_travel_minutes)

          {
            date: date.iso8601,
            label: day_label(date, offset),
            open: hours && hours["open"],
            close: hours && hours["close"],
            slots: bounds ? build_slots(bounds) : []
          }
        end
      end

      def day_label(date, offset)
        case offset
        when 0 then "Сегодня"
        when 1 then "Завтра"
        else date.strftime("%d.%m")
        end
      end

      def build_slots(bounds)
        cur = round_up_to_step(bounds[:earliest])
        slots = []
        while cur <= bounds[:latest]
          slots << cur.strftime("%H:%M")
          cur += SLOT_STEP_MINUTES.minutes
        end
        slots
      end

      # Округляет момент времени ВВЕРХ до ближайшей границы шага (30 мин), не
      # используя только Time#min (иначе секунды/доли теряются и время может
      # округлиться вниз вместо вверх на точной границе)
      def round_up_to_step(time)
        step_seconds = SLOT_STEP_MINUTES * 60
        base = time.beginning_of_day
        seconds_since_midnight = (time - base).to_i
        rounded = (seconds_since_midnight.to_f / step_seconds).ceil * step_seconds
        base + rounded.seconds
      end
    end
  end
end
