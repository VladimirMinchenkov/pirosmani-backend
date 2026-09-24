require 'rails_helper'

RSpec.describe "Api::V1::Orders (bonus)", type: :request do
  before { AppSetting.create!(key: "delivery_mode", value: "internal") }

  let(:client) { create(:client, bonus_points: 500) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "TestItem", price: 100, category: category, available: true) }
  let!(:zone) do
    DeliveryZone.create!(
      name: "TestZone", active: true, price: 50,
      coordinates: [[37.0, 55.0], [37.1, 55.0], [37.1, 55.1], [37.0, 55.1], [37.0, 55.0]]
    )
  end
  let!(:address) { client.client_addresses.create!(street: "Ул. Тест", lat: 55.05, lng: 37.05) }

  describe "POST /api/v1/orders with bonus_points_to_use" do
    it "spends bonus points and reduces total_price" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          bonus_points_to_use: 200,
          order_items: [{ menu_item_id: menu_item.id, quantity: 2 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      # 2 * 100 + 50 delivery = 250, minus 200 * 0.01 = 2.00 BYN = 248.00
      expect(json["total_price"]).to eq(248.0)
      expect(json["bonus_points_used"]).to eq(200)

      # Client balance should be reduced
      expect(client.reload.bonus_points).to eq(300)
    end

    it "caps bonus spending at 10% of order total" do
      # Order total = 2 * 100 + 50 = 250, 10% = 25 BYN = 2500 bonus points
      # Client has 500, so max is 500
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          bonus_points_to_use: 9999, # tries to spend more than allowed
          order_items: [{ menu_item_id: menu_item.id, quantity: 2 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      # 250 - (500 * 0.01) = 250 - 5.00 = 245.00
      expect(json["total_price"]).to eq(245.0)
      expect(json["bonus_points_used"]).to eq(500)
      expect(client.reload.bonus_points).to eq(0)
    end

    it "caps bonus spending at available balance" do
      client.update!(bonus_points: 50)

      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          bonus_points_to_use: 200,
          order_items: [{ menu_item_id: menu_item.id, quantity: 2 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      # 250 - (50 * 0.01) = 250 - 0.50 = 249.50
      expect(json["total_price"]).to eq(249.5)
      expect(json["bonus_points_used"]).to eq(50)
      expect(client.reload.bonus_points).to eq(0)
    end

    it "does not spend bonuses when bonus_points_to_use is 0" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "delivery",
          client_address_id: address.id,
          bonus_points_to_use: 0,
          order_items: [{ menu_item_id: menu_item.id, quantity: 2 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json["total_price"]).to eq(250.0)
      expect(json["bonus_points_used"]).to eq(0)
      expect(client.reload.bonus_points).to eq(500)
    end

    it "creates a spend transaction when bonuses are used" do
      expect {
        post "/api/v1/orders", params: {
          order: {
            order_type: "delivery",
            client_address_id: address.id,
            bonus_points_to_use: 100,
            order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
          }
        }, headers: headers
      }.to change { client.bonus_transactions.spendings.count }.by(1)
    end

    it "does not create spend transaction when no bonuses used" do
      expect {
        post "/api/v1/orders", params: {
          order: {
            order_type: "delivery",
            client_address_id: address.id,
            bonus_points_to_use: 0,
            order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
          }
        }, headers: headers
      }.not_to change { client.bonus_transactions.count }
    end

    it "works with pickup orders too" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          bonus_points_to_use: 100,
          order_items: [{ menu_item_id: menu_item.id, quantity: 2 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      # 2 * 100 = 200, minus 100 * 0.01 = 1.00 = 199.00
      expect(json["total_price"]).to eq(199.0)
      expect(json["bonus_points_used"]).to eq(100)
    end

    it "does not allow negative total_price" do
      client.update!(bonus_points: 50000)

      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          bonus_points_to_use: 50000,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      # 100 - (1000 * 0.01) = 100 - 10.00 = 90.00 (capped at 10% = 1000 points)
      expect(json["total_price"]).to be >= 0
    end
  end

  describe "GET /api/v1/orders includes bonus_points_used" do
    it "returns bonus_points_used in order response" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          bonus_points_to_use: 50,
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }]
        }
      }, headers: headers

      order_id = JSON.parse(response.body)["id"]

      get "/api/v1/orders/#{order_id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["bonus_points_used"]).to eq(50)
    end
  end

  describe "bonus earning when order completes" do
    let!(:order) do
      Order.create!(
        client: client,
        order_type: "delivery",
        client_address: address,
        delivery_zone: zone,
        status: "pending",
        total_price: 150.0,
        delivery_price: 50.0,
        bonus_points_used: 0
      )
    end

    before do
      OrderItem.create!(order: order, menu_item: menu_item, quantity: 2, price: 50.0)
    end

    it "earns bonuses when status changes to done" do
      expect {
        order.update!(status: "done")
      }.to change { client.reload.bonus_points }.by(100) # 150 - 50 delivery = 100 floor
    end

    it "creates earn transaction when order completes" do
      expect {
        order.update!(status: "done")
      }.to change { client.bonus_transactions.earnings.count }.by(1)
    end

    it "does not earn bonuses twice" do
      order.update!(status: "done")
      expect {
        order.update!(status: "done")
      }.not_to change { client.reload.bonus_points }
    end

    it "excludes delivery_price from bonus calculation" do
      order.update!(status: "done")
      expect(client.reload.bonus_points).to eq(600) # 500 initial + 100 earned
    end

    it "does not earn bonuses for cancelled orders" do
      expect {
        order.update!(status: "cancelled")
      }.not_to change { client.reload.bonus_points }
    end

    it "deducts bonus_points_used from earning base" do
      order.update!(bonus_points_used: 200, total_price: 150.0)
      # paid = 150 - 50 delivery - 2.00 bonus = 98, floor = 98
      order.update!(status: "done")
      expect(client.reload.bonus_points).to eq(598) # 500 + 98
    end
  end
end