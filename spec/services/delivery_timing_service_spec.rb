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
end
