require 'rails_helper'

RSpec.describe "Admin courier tracking (mock mode)", type: :request do
  include ActiveJob::TestHelper

  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }
  let!(:client) { create(:client) }
  let!(:client_address) { client.client_addresses.create!(street: "Ул. Тест", lat: 52.10, lng: 23.70) }
  let!(:order) { create(:order, client: client, client_address: client_address, order_type: "delivery", status: "pending") }

  describe "PATCH /admin/v1/orders/:id (status -> cooking)" do
    it "schedules ClaimCreationJob at claim_planned_at (не сразу — синхронизировано с готовностью еды)" do
      expect(order.yandex_claim_id).to be_nil

      expect {
        patch "/admin/v1/orders/#{order.id}", params: { order: { status: "cooking" } }, headers: headers
      }.to have_enqueued_job(ClaimCreationJob).with(order.id)

      expect(response).to have_http_status(:ok)
      order.reload
      expect(order.cooking_started_at).to be_present
      expect(order.claim_planned_at).to be_present
      expect(order.yandex_claim_id).to be_nil # ещё не создана — джоб только запланирован
    end

    it "creates the mock courier claim once the scheduled job actually runs" do
      perform_enqueued_jobs do
        patch "/admin/v1/orders/#{order.id}", params: { order: { status: "cooking" } }, headers: headers
      end

      order.reload
      expect(order.yandex_claim_id).to start_with("mock-")
      expect(order.claim_requested_at).to be_present
      expect(order.courier_name).to be_present
      expect(order.courier_vehicle).to be_present
      expect(order.courier_phone_masked).to be_present
    end

    it "does not schedule a claim twice" do
      patch "/admin/v1/orders/#{order.id}", params: { order: { status: "cooking" } }, headers: headers
      order.reload
      first_claim_planned_at = order.claim_planned_at

      patch "/admin/v1/orders/#{order.id}", params: { order: { status: "delivering" } }, headers: headers
      order.reload
      expect(order.claim_planned_at).to eq(first_claim_planned_at)
    end

    it "does not schedule a claim for pickup orders" do
      pickup_order = create(:order, :pickup, client: client, status: "pending")

      patch "/admin/v1/orders/#{pickup_order.id}", params: { order: { status: "cooking" } }, headers: headers

      pickup_order.reload
      expect(pickup_order.cooking_started_at).to be_nil
      expect(pickup_order.yandex_claim_id).to be_nil
    end
  end

  describe "GET /admin/v1/orders/:id/courier" do
    it "returns 404 when claim not created yet" do
      get "/admin/v1/orders/#{order.id}/courier", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns snapshot after claim is created" do
      YandexDeliveryClaimService.create_and_accept!(order)

      get "/admin/v1/orders/#{order.id}/courier", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status_key"]).to eq("new")
      expect(json["courier_mode"]).to eq("mock")
      expect(json["courier_name"]).to be_present
      expect(json["lat"]).to be_present
      expect(json["lng"]).to be_present
    end
  end

  describe "POST /admin/v1/orders/:id/create_courier_claim" do
    it "manually creates a claim" do
      post "/admin/v1/orders/#{order.id}/create_courier_claim", headers: headers

      expect(response).to have_http_status(:ok)
      order.reload
      expect(order.yandex_claim_id).to be_present
    end
  end

  describe "POST /admin/v1/orders/:id/call_courier" do
    it "returns a masked forwarding number" do
      YandexDeliveryClaimService.create_and_accept!(order)

      post "/admin/v1/orders/#{order.id}/call_courier", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["forwarding_number"]).to eq(order.reload.courier_phone_masked)
    end
  end
end
