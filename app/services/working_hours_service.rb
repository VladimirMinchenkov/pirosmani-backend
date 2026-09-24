# app/services/working_hours_service.rb
class WorkingHoursService
  DAY_KEYS = %w[mon tue wed thu fri sat sun].freeze
  DAY_NAMES = {
    "mon" => "Понедельник", "tue" => "Вторник", "wed" => "Среда",
    "thu" => "Четверг", "fri" => "Пятница", "sat" => "Суббота", "sun" => "Воскресенье"
  }.freeze

  DEFAULT_HOURS = {
    "mon" => { "open" => "11:00", "close" => "22:00" },
    "tue" => { "open" => "11:00", "close" => "22:00" },
    "wed" => { "open" => "11:00", "close" => "22:00" },
    "thu" => { "open" => "11:00", "close" => "22:00" },
    "fri" => { "open" => "11:00", "close" => "23:00" },
    "sat" => { "open" => "11:00", "close" => "23:00" },
    "sun" => { "open" => "11:00", "close" => "22:00" }
  }.freeze

  class << self
    def working_hours
      setting = AppSetting.find_by(key: "cafe_working_hours")
      return DEFAULT_HOURS unless setting&.value.present?
      JSON.parse(setting.value) rescue DEFAULT_HOURS
    end

    def order_stop_minutes
      setting = AppSetting.find_by(key: "cafe_order_stop_minutes")
      (setting&.value || "30").to_i
    end

    def today_key
      DAY_KEYS[Time.current.wday == 0 ? 6 : Time.current.wday - 1] # wday: 0=Sun -> sun, 1=Mon -> mon
    end

    def today_hours
      working_hours[today_key] || DEFAULT_HOURS["mon"]
    end

    def open_now?
      h = today_hours
      return false unless h && h["open"] && h["close"]

      now = time_to_minutes(Time.current)
      open_min = time_to_minutes(parse_time(h["open"]))
      close_min = time_to_minutes(parse_time(h["close"]))

      now >= open_min && now < close_min
    end

    def accepting_orders?
      return false unless open_now?

      h = today_hours
      close_time = parse_time(h["close"])
      stop_time = close_time - order_stop_minutes.minutes
      Time.current < stop_time
    end

    def status_text
      if open_now?
        "Открыто до #{today_hours['close']}"
      else
        tomorrow_hours = working_hours[DAY_KEYS[(DAY_KEYS.index(today_key) + 1) % 7]]
        "Закрыто до #{tomorrow_hours['open']}"
      end
    end

    def minutes_until_close
      return 0 unless open_now?
      close_time = parse_time(today_hours["close"])
      ((close_time - Time.current) / 60).to_i
    end

    def minutes_until_stop
      return 0 unless accepting_orders?
      close_time = parse_time(today_hours["close"])
      stop_time = close_time - order_stop_minutes.minutes
      ((stop_time - Time.current) / 60).to_i
    end

    private

    def parse_time(str)
      parts = str.split(":").map(&:to_i)
      Time.current.change(hour: parts[0], min: parts[1], sec: 0)
    end

    def time_to_minutes(t)
      t.hour * 60 + t.min
    end
  end
end