require 'rails_helper'

RSpec.describe DeliveryTimingService do
  def set_settings(cooking:, courier:, travel:, buffer:)
    AppSetting.create!(key: 'cafe_avg_cooking_minutes', value: cooking.to_s)
    AppSetting.create!(key: 'cafe_avg_courier_arrival_minutes', value: courier.to_s)
    AppSetting.create!(key: 'cafe_avg_travel_minutes', value: travel.to_s)
    AppSetting.create!(key: 'cafe_delivery_buffer_minutes', value: buffer.to_s)
  end

  describe "typical case: P > C (готовка дольше подъезда курьера)" do
    before { set_settings(cooking: 30, courier: 15, travel: 20, buffer: 5) }

    it "claim_delay_minutes = P - C (курьер вызывается позже старта готовки)" do
      expect(described_class.claim_delay_minutes).to eq(15) # 30-15
    end

    it "min_lead_minutes = max(P,C) + T + B" do
      expect(described_class.min_lead_minutes).to eq(55) # 30+20+5
    end

    it "claim_planned_at = cooking_started_at + (P-C)" do
      started = Time.zone.parse("2026-01-01 18:10:00")
      expect(described_class.claim_planned_at(cooking_started_at: started))
        .to eq(started + 15.minutes) # 18:25
    end

    it "cooking_start_planned_at считает назад от scheduled_at" do
      delivery_at = Time.zone.parse("2026-01-01 19:00:00")
      # 19:00 - 5(B) - 20(T) - 30(P) = 18:05
      expect(described_class.cooking_start_planned_at(target_delivery_at: delivery_at))
        .to eq(Time.zone.parse("2026-01-01 18:05:00"))
    end
  end

  describe "edge case: C > P (курьер едет к кафе дольше, чем готовится еда)" do
    before { set_settings(cooking: 10, courier: 20, travel: 20, buffer: 5) }

    it "claim_delay_minutes = 0 (вызываем курьера сразу же при старте готовки)" do
      expect(described_class.claim_delay_minutes).to eq(0)
    end

    it "min_lead_minutes = max(P,C) + T + B, курьер — бутылочное горлышко" do
      expect(described_class.min_lead_minutes).to eq(45) # max(10,20)=20 +20+5
    end

    it "claim_planned_at совпадает с cooking_started_at" do
      started = Time.zone.parse("2026-01-01 18:10:00")
      expect(described_class.claim_planned_at(cooking_started_at: started)).to eq(started)
    end
  end

  describe "edge case: P == C" do
    before { set_settings(cooking: 20, courier: 20, travel: 20, buffer: 5) }

    it "claim_delay_minutes = 0" do
      expect(described_class.claim_delay_minutes).to eq(0)
    end
  end

  describe "использование реального travel_minutes (например, от Yandex check-price) вместо настройки" do
    before { set_settings(cooking: 30, courier: 15, travel: 20, buffer: 5) }

    it "min_lead_minutes учитывает переданный travel_minutes, а не AppSetting" do
      expect(described_class.min_lead_minutes(travel_minutes: 40)).to eq(75) # 30(max)+40+5
    end

    it "cooking_start_planned_at учитывает переданный travel_minutes" do
      delivery_at = Time.zone.parse("2026-01-01 19:00:00")
      # 19:00 - 5(B) - 40(T real) - 30(P) = 17:45
      expect(described_class.cooking_start_planned_at(target_delivery_at: delivery_at, travel_minutes: 40))
        .to eq(Time.zone.parse("2026-01-01 17:45:00"))
    end
  end

  describe "дефолты без настроенных AppSetting (30/15/20/5)" do
    it "min_lead_minutes = 55" do
      expect(described_class.min_lead_minutes).to eq(55)
    end
  end

  describe "lead_minutes_for" do
    before { set_settings(cooking: 30, courier: 15, travel: 20, buffer: 5) }

    it "для delivery == min_lead_minutes" do
      expect(described_class.lead_minutes_for(order_type: "delivery")).to eq(55)
    end

    it "для pickup == cooking + buffer (без курьера/дороги)" do
      expect(described_class.lead_minutes_for(order_type: "pickup")).to eq(35) # 30+5
    end
  end

  # ─── Реальные часы работы: latest_scheduled_at / day_bounds / earliest_available_at ───
  # DEFAULT_HOURS (WorkingHoursService, если cafe_working_hours не настроен):
  #   mon-thu,sun: 11:00–22:00; fri,sat: 11:00–23:00
  # 2026-01-05 — понедельник (проверено через Date#strftime), 2026-01-02 — пятница
  describe "latest_scheduled_at — курьер должен успеть до закрытия" do
    before { set_settings(cooking: 30, courier: 15, travel: 20, buffer: 5) }
    let(:monday) { Date.new(2026, 1, 5) }

    it "delivery: close(22:00) - travel(20) - buffer(5) = 21:35 (курьер — бутылочное горлышко при стандартном order_stop_minutes=30)" do
      expect(described_class.latest_scheduled_at(date: monday, order_type: "delivery"))
        .to eq(Time.zone.local(2026, 1, 5, 21, 35))
    end

    it "pickup: close(22:00) - buffer(5) = 21:55" do
      expect(described_class.latest_scheduled_at(date: monday, order_type: "pickup"))
        .to eq(Time.zone.local(2026, 1, 5, 21, 55))
    end

    it "nil, если кафе в этот день не работает" do
      AppSetting.create!(key: "cafe_working_hours", value: { "mon" => { "open" => "11:00", "close" => "22:00" } }.to_json)
      tuesday = Date.new(2026, 1, 6)
      expect(described_class.latest_scheduled_at(date: tuesday, order_type: "delivery")).to be_nil
    end

    it "когда cafe_order_stop_minutes большой — становится ограничивающим фактором вместо доезда курьера" do
      AppSetting.create!(key: "cafe_order_stop_minutes", value: "120") # кухня не берёт заказы после 20:00
      # stop_at=20:00; kitchen_stop_limit=20:00+30(P)+20(T)+5(B)=20:55; courier_limit=21:35 → latest=min=20:55
      expect(described_class.latest_scheduled_at(date: monday, order_type: "delivery"))
        .to eq(Time.zone.local(2026, 1, 5, 20, 55))
    end
  end

  describe "day_bounds" do
    before { set_settings(cooking: 30, courier: 15, travel: 20, buffer: 5) }
    let(:monday) { Date.new(2026, 1, 5) }

    it "earliest = max(open, from) + lead; latest = latest_scheduled_at, когда день укладывается" do
      from = Time.zone.local(2026, 1, 5, 8, 0) # до открытия
      bounds = described_class.day_bounds(date: monday, order_type: "delivery", from: from)
      expect(bounds[:earliest]).to eq(Time.zone.local(2026, 1, 5, 11, 55)) # open(11:00)+lead(55)
      expect(bounds[:latest]).to eq(Time.zone.local(2026, 1, 5, 21, 35))
    end

    it "nil, если уже слишком поздно, чтобы уложиться в это же рабочее окно (earliest > latest)" do
      from = Time.zone.local(2026, 1, 5, 21, 0) # 21:00 — кухня почти закрывается
      # kitchen_start_floor=max(11:00,21:00)=21:00; earliest=21:00+55=21:55 > latest(21:35)
      expect(described_class.day_bounds(date: monday, order_type: "delivery", from: from)).to be_nil
    end

    it "nil, если кафе не работает в этот день" do
      AppSetting.create!(key: "cafe_working_hours", value: { "mon" => { "open" => "11:00", "close" => "22:00" } }.to_json)
      tuesday = Date.new(2026, 1, 6)
      expect(described_class.day_bounds(date: tuesday, order_type: "delivery")).to be_nil
    end
  end

  describe "earliest_available_at — ищет вперёд по дням, если сегодня уже не укладывается" do
    before { set_settings(cooking: 30, courier: 15, travel: 20, buffer: 5) }

    it "возвращает сегодняшний слот, если укладывается" do
      from = Time.zone.local(2026, 1, 5, 8, 0)
      expect(described_class.earliest_available_at(order_type: "delivery", from: from))
        .to eq(Time.zone.local(2026, 1, 5, 11, 55))
    end

    it "переходит на следующий день, если сегодня уже поздно (21:00, understanding kitchen close ~21:35)" do
      from = Time.zone.local(2026, 1, 5, 21, 0) # понедельник, слишком поздно
      # вторник (default hours) открывается в 11:00 → earliest=11:55 следующего дня
      expect(described_class.earliest_available_at(order_type: "delivery", from: from))
        .to eq(Time.zone.local(2026, 1, 6, 11, 55))
    end

    it "nil, если кафе закрыто на все MAX_DAYS_LOOKAHEAD дней вперёд" do
      AppSetting.create!(key: "cafe_working_hours", value: "{}") # закрыто всегда
      expect(described_class.earliest_available_at(order_type: "delivery")).to be_nil
    end
  end
end
