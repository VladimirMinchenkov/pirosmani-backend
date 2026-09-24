require 'rails_helper'

RSpec.describe "Api::V1::PromoCodes", type: :request do
  describe "POST /api/v1/promo_codes/validate" do
    let!(:promo) { PromoCode.create!(code: "WELCOME20", discount_type: "fixed", discount_value: 20, min_order_price: 100) }

    it "validates a valid promo code" do
      post "/api/v1/promo_codes/validate", params: { code: "WELCOME20", order_total: 150 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["valid"]).to be true
      expect(json["code"]).to eq("WELCOME20")
      expect(json["discount_value"]).to eq(20.0)
    end

    it "rejects below minimum order" do
      post "/api/v1/promo_codes/validate", params: { code: "WELCOME20", order_total: 50 }
      # Контроллер отдаёт 200 + valid:false — фронтенд читает data.error, не HTTP-статус
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["valid"]).to be false
      expect(json["error"]).to be_present
    end

    it "rejects unknown code" do
      post "/api/v1/promo_codes/validate", params: { code: "NOPE", order_total: 200 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["valid"]).to be false
      expect(json["error"]).to be_present
    end
  end
end