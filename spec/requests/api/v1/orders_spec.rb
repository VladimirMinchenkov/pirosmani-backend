require 'rails_helper'

RSpec.describe "Api::V1::Orders", type: :request do
  before { AppSetting.create!(key: "delivery_mode", value: "internal") }
  # ASAP-заказы валидны только когда кафе открыто (WorkingHoursService) —
  # фиксируем время на понедельник, полдень (2026-01-05, DEFAULT_HOURS 11–22),
  # чтобы тест не флакал в зависимости от реального времени запуска
  before { travel_to(Time.zone.local(2026, 1, 5, 12, 0, 0)) }

  let(:client) { create(:client) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "TestItem", price: 150, category: category, available: true) }
  let!(:addon_group) { AddonGroup.create!(name: "TestSauces", min_selection: 0) }
  let!(:addon) { addon_group.addons.create!(name: "Соус", price: 20) }
  let!(:zone) do
    DeliveryZone.create!(
      name: "TestZone", active: true, price: 50,
      coordinates: [[37.0, 55.0], [37.1, 55.0], [37.1, 55.1], [37.0, 55.1], [37.0, 55.0]]
    )
  end
  let!(:address) { client.client_addresses.create!(street: "Ул. Тест", lat: 55.05, lng: 37.05) }

  describe "POST /api/v1/orders — клиент без телефона (Telegram Mini App до requestContact)" do
    it "отказывает в создании заказа с понятной ошибкой" do
      telegram_client = Client.create!(telegram_user_id: 123456, name: "Гость", phone: nil)
      tg_headers = { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: telegram_client.id)}" }

      post "/api/v1/orders", params: {
        order: { order_type: "pickup", order_items: [{ menu_item_id: menu_item.id, quantity: 1 }] }
      }, headers: tg_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to match(/номер телефона/)
    end
  end

  describe "POST /api/v1/orders (delivery)" do
    it "уведомляет Telegram о новом заказе (best-effort, не блокирует создание)" do
      expect(TelegramOrderNotifierService).to receive(:notify_new_order!)

      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end

    it "creates an order with address, addons and calculates totals" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          order_items: [
            { menu_item_id: menu_item.id, quantity: 2, addon_ids: [addon.id] }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["order_type"]).to eq("delivery")
      expect(json["status"]).to eq("pending")
      # Внутренняя себестоимость доставки (реальная цена заявки Yandex) —
      # не для клиента, только для админки (см. Admin::V1::OrdersController)
      expect(json).not_to have_key("yandex_actual_claim_price")
      expect(json["delivery_price"]).to eq(50.0)
      expect(json["total_price"]).to eq((150 * 2) + (20 * 2) + 50.0)
      expect(json["order_items"].first["addons"].first["name"]).to eq("Соус")
    end
  end

  describe "POST /api/v1/orders (pickup)" do
    it "creates a pickup order without delivery price" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["order_type"]).to eq("pickup")
      expect(json["delivery_price"]).to eq(0.0)
      expect(json["total_price"]).to eq(150.0)
    end
  end

  describe "GET /api/v1/orders" do
    it "returns only current client's orders" do
      post "/api/v1/orders", params: {
        order: { order_type: "pickup", order_items: [{ menu_item_id: menu_item.id, quantity: 1 }] }
      }, headers: headers

      get "/api/v1/orders", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
    end
  end

  describe "unauthorized" do
    it "rejects without client" do
      post "/api/v1/orders", params: { order: { order_type: "pickup", order_items: [] } }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
