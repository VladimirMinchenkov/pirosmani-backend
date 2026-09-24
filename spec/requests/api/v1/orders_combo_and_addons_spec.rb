require 'rails_helper'

RSpec.describe "Order creation: combos and addons", type: :request do
  before { AppSetting.create!(key: "delivery_mode", value: "internal") }
  # ASAP-заказы валидны только когда кафе открыто (WorkingHoursService) —
  # фиксируем время на понедельник, полдень (2026-01-05, DEFAULT_HOURS 11–22),
  # чтобы тест не флакал в зависимости от реального времени запуска
  before { travel_to(Time.zone.local(2026, 1, 5, 12, 0, 0)) }

  let(:client) { create(:client, bonus_points: 0) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "Хинкали", price: 25.0, category: category, available: true) }
  let!(:menu_item2) { MenuItem.create!(name: "Хачапури", price: 35.0, category: category, available: true) }

  let!(:addon_group) { AddonGroup.create!(name: "Соусы", min_selection: 0, max_selection: 2) }
  let!(:addon) { Addon.create!(addon_group: addon_group, name: "Ткемали", price: 2.5, position: 0) }

  let!(:combo) do
    combo = Combo.create!(name: "Комбо дня", price: 45.0, active: true)
    combo.combo_items.create!(menu_item: menu_item, quantity: 2)
    combo.combo_items.create!(menu_item: menu_item2, quantity: 1)
    combo
  end

  describe "order with a variant-style item + addon (attached to the same order_item)" do
    it "creates the order_item with addon correctly linked" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          order_items: [
            { menu_item_id: menu_item.id, quantity: 1, addon_ids: [addon.id] }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      # 25 (блюдо) + 2.5 (доп) = 27.5
      expect(json["total_price"]).to eq(27.5)

      order_item = json["order_items"].first
      expect(order_item["menu_item_id"]).to eq(menu_item.id)
      expect(order_item["addons"].size).to eq(1)
      expect(order_item["addons"].first["name"]).to eq("Ткемали")
    end
  end

  describe "order with a combo item" do
    it "creates order_item with combo_id (not menu_item_id) and correct combo price" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          combo_items: [
            { combo_id: combo.id, quantity: 1 }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["total_price"]).to eq(45.0)

      order_item = json["order_items"].first
      expect(order_item["menu_item_id"]).to be_nil
      expect(order_item["combo_id"]).to eq(combo.id)
      expect(order_item["name"]).to eq("Комбо дня")
    end
  end

  describe "order mixing regular items and combos" do
    it "sums both correctly" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          order_items: [{ menu_item_id: menu_item.id, quantity: 1 }],
          combo_items: [{ combo_id: combo.id, quantity: 1 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      # 25 (блюдо) + 45 (комбо) = 70
      expect(json["total_price"]).to eq(70.0)
      expect(json["order_items"].size).to eq(2)
    end
  end

  describe "order with only combo_items (no order_items key at all)" do
    it "does not raise on missing order_items param" do
      post "/api/v1/orders", params: {
        order: {
          order_type: "pickup",
          combo_items: [{ combo_id: combo.id, quantity: 2 }]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["total_price"]).to eq(90.0)
    end
  end
end
