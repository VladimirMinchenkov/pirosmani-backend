require 'rails_helper'

RSpec.describe "GET /api/v1/menu/personalized", type: :request do
  let(:client) { create(:client) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "Хинкали", price: 25.0, category: category, available: true) }
  let!(:menu_item2) { MenuItem.create!(name: "Хачапури", price: 35.0, category: category, available: true) }

  it "requires authorization" do
    get "/api/v1/menu/personalized"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns order_count: 0 and nil repeat_order for a client with no orders" do
    get "/api/v1/menu/personalized", headers: headers

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["order_count"]).to eq(0)
    expect(json["repeat_order"]).to be_nil
    expect(json["frequent_items"]).to eq([])
  end

  it "returns repeat_order built from the most recent order" do
    order = Order.create!(client: client, status: "done", order_type: "pickup", total_price: 25.0, delivery_price: 0)
    order.order_items.create!(menu_item: menu_item, quantity: 1, price: menu_item.price)

    get "/api/v1/menu/personalized", headers: headers

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["order_count"]).to eq(1)
    expect(json["repeat_order"]["id"]).to eq(order.id)
    expect(json["repeat_order"]["all_available"]).to be true
    expect(json["repeat_order"]["items"].first["name"]).to eq("Хинкали")
  end

  it "marks repeat_order as not all_available when an item became unavailable" do
    order = Order.create!(client: client, status: "done", order_type: "pickup", total_price: 25.0, delivery_price: 0)
    order.order_items.create!(menu_item: menu_item, quantity: 1, price: menu_item.price)
    menu_item.update!(available: false)

    get "/api/v1/menu/personalized", headers: headers

    json = JSON.parse(response.body)
    expect(json["repeat_order"]["all_available"]).to be false
  end

  it "returns frequent_items (batch-loaded, no N+1) when there are 3+ orders" do
    3.times do
      order = Order.create!(client: client, status: "done", order_type: "pickup", total_price: 25.0, delivery_price: 0)
      order.order_items.create!(menu_item: menu_item, quantity: 2, price: menu_item.price)
      order.order_items.create!(menu_item: menu_item2, quantity: 1, price: menu_item2.price)
    end

    get "/api/v1/menu/personalized", headers: headers

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["order_count"]).to eq(3)
    expect(json["frequent_items"].size).to eq(2)
    top = json["frequent_items"].first
    expect(top["menu_item_id"]).to eq(menu_item.id)
    expect(top["order_count"]).to eq(6) # 2 * 3 заказов
  end

  it "excludes unavailable menu items from frequent_items" do
    3.times do
      order = Order.create!(client: client, status: "done", order_type: "pickup", total_price: 25.0, delivery_price: 0)
      order.order_items.create!(menu_item: menu_item, quantity: 1, price: menu_item.price)
    end
    menu_item.update!(available: false)

    get "/api/v1/menu/personalized", headers: headers

    json = JSON.parse(response.body)
    expect(json["frequent_items"]).to be_empty
  end
end
