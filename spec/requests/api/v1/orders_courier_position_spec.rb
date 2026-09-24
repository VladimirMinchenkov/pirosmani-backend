require 'rails_helper'

RSpec.describe "Client courier tracking (mock mode)", type: :request do
  let(:client) { create(:client) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let!(:client_address) { client.client_addresses.create!(street: "Ул. Тест", lat: 52.10, lng: 23.70) }
  let!(:order) { create(:order, client: client, client_address: client_address, order_type: "delivery") }

  describe "GET /api/v1/orders/:id/courier_position" do
    it "returns 404 before the claim is created" do
      get "/api/v1/orders/#{order.id}/courier_position", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns status/position/eta, without exposing claim_id or phone" do
      YandexDeliveryClaimService.create_and_accept!(order)

      get "/api/v1/orders/#{order.id}/courier_position", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to have_key("claim_id")
      expect(json["status_key"]).to eq("new")
      expect(json["courier_name"]).to be_present
      expect(json["eta_minutes"]).to be_a(Integer)
    end

    it "does not allow accessing another client's order" do
      other_client = create(:client, phone: "+79990001111")
      other_order = create(:order, client: other_client)

      get "/api/v1/orders/#{other_order.id}/courier_position", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/orders/:id/call_courier" do
    it "returns a masked forwarding number" do
      YandexDeliveryClaimService.create_and_accept!(order)

      post "/api/v1/orders/#{order.id}/call_courier", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["forwarding_number"]).to eq(order.reload.courier_phone_masked)
    end
  end
end
