require 'rails_helper'

RSpec.describe "Admin::V1::PromoCodes", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe 'GET /admin/v1/promo_codes' do
    it 'returns all promo codes' do
      create(:promo_code, code: 'SALE10')
      create(:promo_code, code: 'SALE20')

      get '/admin/v1/promo_codes', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(2)
    end
  end

  describe 'POST /admin/v1/promo_codes' do
    it 'creates a promo code' do
      post '/admin/v1/promo_codes',
           params: {
             promo_code: {
               code: 'WELCOME',
               discount_type: 'fixed',
               discount_value: 5.00,
               active: true,
               usage_limit: 50
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['code']).to eq('WELCOME')
    end

    it 'returns 422 with invalid params' do
      post '/admin/v1/promo_codes',
           params: { promo_code: { code: '' } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /admin/v1/promo_codes/:id' do
    let(:promo) { create(:promo_code) }

    it 'updates the promo code' do
      patch "/admin/v1/promo_codes/#{promo.id}",
            params: { promo_code: { active: false } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['active']).to be false
    end
  end

  describe 'DELETE /admin/v1/promo_codes/:id' do
    let(:promo) { create(:promo_code) }

    it 'deletes the promo code' do
      delete "/admin/v1/promo_codes/#{promo.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(PromoCode.exists?(promo.id)).to be false
    end
  end
end