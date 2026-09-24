require 'rails_helper'

RSpec.describe "Api::V1::DeliverySlots", type: :request do
  # 2026-01-05 — понедельник, DEFAULT_HOURS: 11:00–22:00 (проверено через Date#strftime)
  let(:monday_noon) { Time.zone.local(2026, 1, 5, 12, 0, 0) }

  around do |example|
    travel_to(monday_noon) { example.run }
  end

  describe "GET /api/v1/delivery_slots" do
    it "возвращает accepting_asap=true, когда кафе открыто" do
      get "/api/v1/delivery_slots", params: { order_type: "delivery" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["accepting_asap"]).to eq(true)
    end

    it "возвращает min_lead_minutes = 55 при дефолтных настройках (delivery)" do
      get "/api/v1/delivery_slots", params: { order_type: "delivery" }
      json = JSON.parse(response.body)
      expect(json["min_lead_minutes"]).to eq(55)
    end

    it "возвращает 3 дня, первый — 'Сегодня'" do
      get "/api/v1/delivery_slots", params: { order_type: "delivery" }
      json = JSON.parse(response.body)
      expect(json["days"].length).to eq(3)
      expect(json["days"][0]["label"]).to eq("Сегодня")
      expect(json["days"][0]["date"]).to eq("2026-01-05")
      expect(json["days"][1]["label"]).to eq("Завтра")
    end

    it "сегодняшние слоты начинаются не раньше earliest (12:00 + 55 мин округлено вверх до 13:00) и не позже 21:35" do
      get "/api/v1/delivery_slots", params: { order_type: "delivery" }
      json = JSON.parse(response.body)
      today_slots = json["days"][0]["slots"]
      expect(today_slots.first).to eq("13:00") # 12:55 округлено вверх до шага 30 мин
      expect(today_slots.last).to eq("21:30") # последний 30-минутный слот <= 21:35
      expect(today_slots).to all(satisfy { |s| s <= "21:35" })
    end

    it "самовывоз использует свой (меньший) lead — слоты начинаются раньше" do
      get "/api/v1/delivery_slots", params: { order_type: "pickup" }
      json = JSON.parse(response.body)
      # lead_minutes_for(pickup) = 30(cooking)+5(buffer)=35 → earliest=12:35→округление до 13:00
      expect(json["days"][0]["slots"].first).to eq("13:00")
      expect(json["days"][0]["slots"].last).to eq("21:30") # <= latest(21:55)
    end

    it "день, когда кафе закрыто, возвращает пустой массив слотов" do
      AppSetting.create!(key: "cafe_working_hours", value: { "mon" => { "open" => "11:00", "close" => "22:00" } }.to_json)
      get "/api/v1/delivery_slots", params: { order_type: "delivery" }
      json = JSON.parse(response.body)
      tuesday = json["days"].find { |d| d["date"] == "2026-01-06" }
      expect(tuesday["slots"]).to eq([])
      expect(tuesday["open"]).to be_nil
    end

    # Пользователь задал вопрос: "если предзаказ на завтра, как мы можем сейчас
    # посчитать доставку?" — живой замер трафика от Yandex релевантен только
    # для СЕГОДНЯ; для завтра/послезавтра должна использоваться усреднённая
    # настройка cafe_avg_travel_minutes, а не мгновенный замер "сейчас"
    it "travel_minutes (живой замер Yandex) влияет только на сегодняшний день, не на завтра" do
      # travel_minutes=200 — заведомо нереалистичный "живой" замер трафика
      get "/api/v1/delivery_slots", params: { order_type: "delivery", travel_minutes: 200 }
      json = JSON.parse(response.body)

      today = json["days"][0]
      tomorrow = json["days"][1]

      # Сегодня: lead = max(30,15)+200(live)+5 = 235 мин → earliest=12:00+235=15:55→16:00
      expect(today["slots"].first).to eq("16:00")

      # Завтра: lead = max(30,15)+20(avg, НЕ живой замер)+5 = 55 мин → earliest=11:00+55=11:55→12:00
      expect(tomorrow["slots"].first).to eq("12:00")
    end
  end
describe "когда кафе физически закрыто прямо сейчас" do
  # переопределяем время из внешнего around-блока вместо второго вложенного
  # travel_to (иначе rspec-rails ругается на "nested travel_to")
  let(:monday_noon) { Time.zone.local(2026, 1, 5, 22, 30, 0) }


    it "accepting_asap=false, но завтрашний день всё равно содержит слоты" do
      get "/api/v1/delivery_slots", params: { order_type: "delivery" }
      json = JSON.parse(response.body)
      expect(json["accepting_asap"]).to eq(false)
      tomorrow = json["days"].find { |d| d["date"] == "2026-01-06" }
      expect(tomorrow["slots"]).not_to be_empty
    end

    it "сегодняшний день (уже почти полночь) не содержит слотов — не укладывается в рабочее окно" do
      get "/api/v1/delivery_slots", params: { order_type: "delivery" }
      json = JSON.parse(response.body)
      today = json["days"].find { |d| d["date"] == "2026-01-05" }
      expect(today["slots"]).to eq([])
    end
  end
end
