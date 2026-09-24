require 'rails_helper'

RSpec.describe "Order flow: combos, promos, delivery", type: :request do
  before { AppSetting.create!(key: "delivery_mode", value: "internal") }

  let(:client) { create(:client, bonus_points: 0) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "Хинкали", price: 25.0, category: category, available: true) }
  let!(:menu_item2) { MenuItem.create!(name: "Хачапури", price: 35.0, category: category, available: true) }
  let!(:zone) do
    DeliveryZone.create!(
      name: "Центр", active: true, price: 10.0,
      coordinates: [[37.0, 55.0], [37.1, 55.0], [37.1, 55.1], [37.0, 55.1], [37.0, 55.0]]
    )
  end
  let!(:address) { client.client_addresses.create!(street: "Ул. Тест", lat: 55.05, lng: 37.05) }

  describe "order with multiple items" do
    it "calculates total correctly for multiple items" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          order_items: [
            { menu_item_id: menu_item.id, quantity: 2 },
            { menu_item_id: menu_item2.id, quantity: 1 }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      # 2*25 + 1*35 + 10 delivery = 95
      expect(json["total_price"]).to eq(95.0)
    end
  end

  describe "pickup order" do
    it "has zero delivery price" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          order_items: [{ menu_item_id: menu_item.id, quantity: 2 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["total_price"]).to eq(50.0) # 2*25, no delivery
    end
  end

  describe "delivery zone validation" do
    it "rejects order when address is outside delivery zone" do
      far_address = client.client_addresses.create!(street: "Далеко", lat: 60.0, lng: 40.0)

      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: far_address.id,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("not available")
    end
  end

  describe "promo code application" do
    let!(:promo) do
      PromoCode.create!(
        code: "WELCOME20",
        discount_type: "percent",
        discount_value: 20,
        active: true,
        usage_limit: 10
      )
    end

    it "applies percent promo to order" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          promo_code_id: promo.id,
          order_items: [{ menu_item_id: menu_item.id, quantity: 4 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      # 4*25 = 100, minus 20% = 80
      expect(json["total_price"]).to eq(80.0)
    end
  end

  describe "large order" do
    it "handles order with 10+ items" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          order_items: [{ menu_item_id: menu_item.id, quantity: 10 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["total_price"]).to eq(250.0)
    end
  end

  describe "unavailable menu item" do
    it "still creates order with unavailable item (availability checked client-side)" do
      menu_item.update!(available: false)

      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      # Сервер не проверяет available — это ответственность фронтенда
      expect(response).to have_http_status(:created)
    end
  end
end