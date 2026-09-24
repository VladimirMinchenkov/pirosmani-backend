require 'rails_helper'

RSpec.describe "Order creation: scheduled_at validation", type: :request do
  before { AppSetting.create!(key: "delivery_mode", value: "internal") }

  let(:client) { create(:client) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "Хинкали", price: 25.0, category: category, available: true) }
  let!(:zone) do
    DeliveryZone.create!(
      name: "Центр", active: true, price: 10.0,
      coordinates: [[37.0, 55.0], [37.1, 55.0], [37.1, 55.1], [37.0, 55.1], [37.0, 55.0]]
    )
  end
  let!(:address) { client.client_addresses.create!(street: "Ул. Тест", lat: 55.05, lng: 37.05) }

  # 2026-01-05 — понедельник (проверено через Date#strftime), DEFAULT_HOURS: 11:00–22:00.
  # Замораживаем время на середину дня, чтобы тесты не зависели от реального времени
  # запуска (иначе "N минут/часов от текущего момента" может улететь за закрытие
  # кафе и тест начнёт флакать в зависимости от часа суток)
  let(:monday_noon) { Time.zone.local(2026, 1, 5, 12, 0, 0) }

  around do |example|
    travel_to(monday_noon) { example.run }
  end

  describe "pickup order" do
    it "rejects scheduled_at too soon (< cooking + buffer)" do
      # default: cooking=30, buffer=5 => min 35 min
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          scheduled_at: 10.minutes.from_now.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("слишком близко")
    end

    it "accepts scheduled_at far enough in the future" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          scheduled_at: 2.hours.from_now.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  describe "delivery order (internal zone pricing, no real Yandex ETA)" do
    it "rejects scheduled_at too soon (< max(cooking,courier) + travel + buffer = 55 min by default)" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: 20.minutes.from_now.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("слишком близко")
    end

    it "accepts scheduled_at far enough (>= 55 min by default)" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: 2.hours.from_now.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(Time.zone.parse(json["scheduled_at"])).to be_within(5.seconds).of(2.hours.from_now)
    end

    it "does not validate when scheduled_at is absent (ASAP order)" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  # ─── Реальные часы работы (баги #1, #3, #4 из аудита) ───

  describe "предзаказ на время после закрытия кафе (курьер не успеет доехать)" do
    it "rejects — 21:50 позже, чем latest_scheduled_at (21:35 = close 22:00 - travel 20 - buffer 5)" do
      target = Time.zone.local(2026, 1, 5, 21, 50, 0)
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("не успеем")
    end

    it "accepts — 21:30 укладывается (<= 21:35)" do
      target = Time.zone.local(2026, 1, 5, 21, 30, 0)
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  describe "предзаказ на день, когда кафе не работает" do
    before do
      AppSetting.create!(key: "cafe_working_hours", value: { "mon" => { "open" => "11:00", "close" => "22:00" } }.to_json)
    end

    it "rejects — во вторник (не указан в cafe_working_hours) кафе закрыто" do
      target = Time.zone.local(2026, 1, 6, 15, 0, 0) # вторник
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("не работает")
    end
  end

  describe "предзаказ раньше открытия кафе" do
    it "rejects — 08:00 раньше открытия (11:00), даже с учётом лид-тайма" do
      target = Time.zone.local(2026, 1, 5, 8, 0, 0)
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("слишком близко")
    end
  end

  # ─── ASAP-заказы: кафе закрыто "прямо сейчас" (баг #3) ───
describe "ASAP-заказ, когда кафе физически закрыто" do
  # понедельник, после закрытия (22:00) — переопределяем время из внешнего
  # around-блока вместо второго вложенного travel_to (иначе rspec-rails
  # ругается на "nested travel_to")
  let(:monday_noon) { Time.zone.local(2026, 1, 5, 22, 30, 0) }


    it "отказывает в ASAP-заказе — нельзя принять заказ 'прямо сейчас', когда кафе закрыто" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("не принимаются")
    end

    it "но позволяет оформить предзаказ на завтра (после открытия+лид-тайма)" do
      target = Time.zone.local(2026, 1, 6, 12, 0, 0) # вторник, днём
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  # ─── "Живой" трафик Yandex не должен влиять на тайминг предзаказа ───
  # Пользователь задал вопрос: "если предзаказ на завтра, как мы можем сейчас
  # посчитать доставку?" — ответ: для предзаказа НЕ используем мгновенный
  # замер трафика (он релевантен только "прямо сейчас"), а усреднённую
  # настройку cafe_avg_travel_minutes. См. OrdersController#effective_travel_minutes.
  describe "живая оценка Yandex ETA игнорируется для предзаказов (используется усреднённая настройка)" do
    before { AppSetting.find_by(key: "delivery_mode").update!(value: "yandex") }

    it "отклоняет предзаказ, если он валиден только при (неверном) использовании живой оценки" do
      # avg_travel_minutes по умолчанию = 20 => lead(delivery) = max(30,15)+20+5 = 55 мин
      # earliest (используя avg) = 12:00 + 55 = 12:55
      # Если бы код ошибочно использовал "живую" оценку estimated_minutes=200,
      # lead был бы = max(30,15)+200+5 = 235 мин => earliest = 15:55, и 13:00 был бы отклонён.
      # Раз мы ожидаем :created — значит avg используется, а не живой замер.
      target = monday_noon + 60.minutes # 13:00 — после avg-earliest(12:55), но задолго до "живого" earliest(15:55)
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          estimated_cost: 15.0,
          estimated_minutes: 200, # заведомо неверный "живой" замер трафика
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end

    it "ASAP-заказ (без scheduled_at), напротив, использует живую оценку как travel_minutes" do
      # Косвенная проверка: раз для ASAP нет day_bounds-валидации по scheduled_at,
      # просто убеждаемся, что заказ создаётся успешно с живой оценкой —
      # основной сценарий (предзаказ игнорирует живую оценку) покрыт тестом выше.
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          estimated_cost: 15.0,
          estimated_minutes: 5,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  # ─── "Живая" цена Yandex не должна использоваться для предзаказа ───
  # Уточнение бизнеса: используемый тариф — "Экспресс"/курьер (динамическое
  # ценообразование по спросу/времени суток, как у такси), а НЕ грузовой
  # Cargo с дистанционным тарифом. Поэтому для предзаказа цена фиксируется
  # по стабильному тарифу ЗОНЫ (задаётся админом), а не по сиюминутной
  # котировке Yandex — бизнес коммитится клиенту на цену уже при оформлении,
  # риск разницы фактической стоимости логистики несёт кафе, а не клиент.
  describe "живая цена Yandex игнорируется для предзаказов (используется тариф зоны)" do
    before { AppSetting.find_by(key: "delivery_mode").update!(value: "yandex") }

    it "заряжает клиенту цену зоны (10.0), а не поддельную живую котировку (999.0)" do
      target = monday_noon + 60.minutes # 13:00 — валидный слот предзаказа
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          estimated_cost: 999.0, # заведомо неверная "живая" котировка
          estimated_minutes: 5,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["delivery_price"]).to eq(10.0) # zone.price, НЕ 999.0
    end

    it "ASAP-заказ, напротив, заряжает по живой котировке" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          estimated_cost: 42.0,
          estimated_minutes: 5,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["delivery_price"]).to eq(42.0)
    end
  end

  # ─── Регресс: cooking_start_planned_at должен реально устанавливаться ───
  # (метод assign_cooking_start_planned_at был определён, но никогда не
  # вызывался в create — поле оставалось nil для всех предзаказов)
  describe "cooking_start_planned_at" do
    it "устанавливается при создании предзаказа (target - buffer - travel(avg) - cooking)" do
      target = Time.zone.local(2026, 1, 5, 19, 0, 0)
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          scheduled_at: target.iso8601,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      # 19:00 - 5(buffer) - 20(avg travel) - 30(avg cooking) = 18:05
      expect(Time.zone.parse(json["cooking_start_planned_at"])).to be_within(5.seconds).of(Time.zone.local(2026, 1, 5, 18, 5, 0))
    end

    it "остаётся nil для ASAP-заказа (без scheduled_at)" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["cooking_start_planned_at"]).to be_nil
    end
  end
end
