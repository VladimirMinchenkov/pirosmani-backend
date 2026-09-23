require 'rails_helper'

RSpec.describe "Api::V1::BonusTransactions", type: :request do
  let(:client) { create(:client, bonus_points: 200) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let(:order) { create(:order, client: client, total_price: 50.00) }

  describe "GET /api/v1/bonus_transactions" do
    before do
      create(:bonus_transaction, :earn, client: client, order: order, amount: 100, created_at: 3.days.ago)
      create(:bonus_transaction, :spend, client: client, order: order, amount: 30, created_at: 2.days.ago)
      create(:bonus_transaction, :earn, client: client, order: order, amount: 50, created_at: 1.day.ago)
    end

    it "returns bonus_points and transaction history" do
      get "/api/v1/bonus_transactions", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["bonus_points"]).to eq(200)
      expect(json["transactions"].size).to eq(3)
    end

    it "returns transactions in reverse chronological order" do
      get "/api/v1/bonus_transactions", headers: headers

      json = JSON.parse(response.body)
      amounts = json["transactions"].map { |t| t["amount"] }
      expect(amounts).to eq([50, 30, 100])
    end

    it "includes all required transaction fields" do
      get "/api/v1/bonus_transactions", headers: headers

      json = JSON.parse(response.body)
      tx = json["transactions"].first
      expect(tx["id"]).to be_present
      expect(tx["kind"]).to be_in(%w[earn spend])
      expect(tx["amount"]).to be > 0
      expect(tx["description"]).to be_present
      expect(tx["order_id"]).to eq(order.id)
      expect(tx["created_at"]).to be_present
    end

    it "returns empty transactions array for client with no history" do
      new_client = create(:client, bonus_points: 0)
      headers = { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: new_client.id)}" }

      get "/api/v1/bonus_transactions", headers: headers

      json = JSON.parse(response.body)
      expect(json["bonus_points"]).to eq(0)
      expect(json["transactions"]).to eq([])
    end

    it "returns 401 without authorization" do
      get "/api/v1/bonus_transactions"

      expect(response).to have_http_status(:unauthorized)
    end

    it "limits to 50 most recent transactions" do
      60.times do |i|
        create(:bonus_transaction, :earn, client: client, order: order, amount: 1, created_at: i.hours.ago)
      end

      get "/api/v1/bonus_transactions", headers: headers

      json = JSON.parse(response.body)
      expect(json["transactions"].size).to be <= 50
    end
  end
end