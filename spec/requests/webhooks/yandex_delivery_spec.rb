require 'rails_helper'

RSpec.describe "Webhooks::YandexDelivery", type: :request do
  let(:client) { create(:client) }
  let(:address) { client.client_addresses.create!(street: "Ул. Тест", lat: 55.05, lng: 37.05) }
  let!(:order) do
    Order.create!(
      client: client, order_type: "delivery", client_address: address,
      status: "pending", total_price: 50.0, delivery_price: 10.0,
      yandex_claim_id: "claim-123", yandex_claim_status: "new"
    )
  end

  describe "POST /webhooks/yandex_delivery" do
    it "обновляет yandex_claim_status по claim_id" do
      post "/webhooks/yandex_delivery", params: { claim_id: "claim-123", status: "performer_found" }

      expect(response).to have_http_status(:ok)
      expect(order.reload.yandex_claim_status).to eq("performer_found")
    end

    it "обновляет courier-снапшот, если он присутствует в payload" do
      post "/webhooks/yandex_delivery", params: {
        claim_id: "claim-123", status: "performer_found",
        performer: { name: "Иван Иванов", car: { model: "Lada Vesta", number: "А123ВС7" }, phone_masked: "+375290000000" }
      }

      order.reload
      expect(order.courier_name).to eq("Иван Иванов")
      expect(order.courier_vehicle).to eq("Lada Vesta · А123ВС7")
      expect(order.courier_phone_masked).to eq("+375290000000")
    end

    it "принимает вложенную форму claim: { id:, status: }" do
      post "/webhooks/yandex_delivery", params: { claim: { id: "claim-123", status: "delivered" } }

      expect(response).to have_http_status(:ok)
      expect(order.reload.yandex_claim_status).to eq("delivered")
    end

    it "возвращает 400, если claim_id или status отсутствуют" do
      post "/webhooks/yandex_delivery", params: { status: "delivered" }
      expect(response).to have_http_status(:bad_request)
    end

    it "возвращает 200 (не 404/500), если заказ с таким claim_id не найден — чтобы Yandex не ретраил бесконечно" do
      post "/webhooks/yandex_delivery", params: { claim_id: "unknown-claim", status: "delivered" }
      expect(response).to have_http_status(:ok)
    end
  end
end
