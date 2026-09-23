require 'rails_helper'

RSpec.describe "Api::V1::Profile", type: :request do
  let(:client) { create(:client, bonus_points: 150, name: "Test User") }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }

  describe "GET /api/v1/profile" do
    it "returns client profile with bonus_points" do
      get "/api/v1/profile", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(client.id)
      expect(json["phone"]).to eq(client.phone)
      expect(json["name"]).to eq("Test User")
      expect(json["bonus_points"]).to eq(150)
      expect(json["created_at"]).to be_present
    end

    it "returns 401 without authorization" do
      get "/api/v1/profile"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Authorization required")
    end

    it "returns 401 with invalid token" do
      get "/api/v1/profile", headers: { "Authorization" => "Bearer invalid_token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns bonus_points as 0 for new client" do
      new_client = create(:client, bonus_points: 0)
      headers = { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: new_client.id)}" }

      get "/api/v1/profile", headers: headers

      json = JSON.parse(response.body)
      expect(json["bonus_points"]).to eq(0)
    end
  end
end