require 'rails_helper'

RSpec.describe "Api::V1::PhoneVerifications", type: :request do
  describe "POST /api/v1/phone_verifications" do
    it "generates and stores a new OTP code" do
      expect {
        post "/api/v1/phone_verifications", params: { phone: "+79991234567" }
      }.to change(OtpCode, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "rejects empty phone" do
      post "/api/v1/phone_verifications", params: {}
      expect(response).to have_http_status(:bad_request)
    end
  end
end
