require 'rails_helper'

RSpec.describe "Api::V1::Sessions", type: :request do
  describe "POST /api/v1/sessions" do
    it "creates a client if not exists and issues access + refresh tokens" do
      otp = OtpCode.generate_for("+79991234567")
      post "/api/v1/sessions", params: { phone: "+79991234567", code: otp.code }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["access_token"]).to be_present
      expect(json["refresh_token"]).to be_present
      expect(json["client"]["phone"]).to eq("+79991234567")
      expect(Client.find_by(phone: "+79991234567")).to be_present
    end

    it "reuses existing client with the same phone" do
      client = create(:client, phone: "+79991234567")
      otp = OtpCode.generate_for("+79991234567")

      post "/api/v1/sessions", params: { phone: "+79991234567", code: otp.code }

      json = JSON.parse(response.body)
      expect(json["client"]["id"]).to eq(client.id)
    end

    it "rejects invalid code" do
      OtpCode.generate_for("+79991234567")
      post "/api/v1/sessions", params: { phone: "+79991234567", code: "000000" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects expired code" do
      otp = OtpCode.create!(phone: "+79991234567", code: "123456", expires_at: 1.hour.ago)
      post "/api/v1/sessions", params: { phone: "+79991234567", code: otp.code }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects missing phone" do
      post "/api/v1/sessions", params: { code: "123456" }
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects missing code" do
      post "/api/v1/sessions", params: { phone: "+79991234567" }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /api/v1/sessions/refresh" do
    it "rotates refresh token and issues a new access token" do
      client = create(:client)
      session = Auth::IssueClientSession.call(client)

      post "/api/v1/sessions/refresh", params: { refresh_token: session[:refresh_token] }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["access_token"]).to be_present
      expect(json["refresh_token"]).not_to eq(session[:refresh_token])

      old_record = RefreshToken.find_by(token: RefreshToken.hash_token(session[:refresh_token]))
      expect(old_record.revoked_at).to be_present
    end

    it "rejects an already used (revoked) refresh token" do
      client = create(:client)
      session = Auth::IssueClientSession.call(client)

      post "/api/v1/sessions/refresh", params: { refresh_token: session[:refresh_token] }
      post "/api/v1/sessions/refresh", params: { refresh_token: session[:refresh_token] }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects unknown refresh token" do
      post "/api/v1/sessions/refresh", params: { refresh_token: "bogus" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/sessions" do
    it "revokes the refresh token" do
      client = create(:client)
      session = Auth::IssueClientSession.call(client)

      delete "/api/v1/sessions", params: { refresh_token: session[:refresh_token] }

      expect(response).to have_http_status(:no_content)
      record = RefreshToken.find_by(token: RefreshToken.hash_token(session[:refresh_token]))
      expect(record.revoked_at).to be_present
    end
  end
end
