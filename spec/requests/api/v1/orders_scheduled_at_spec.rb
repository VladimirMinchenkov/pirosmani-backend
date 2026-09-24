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
end
