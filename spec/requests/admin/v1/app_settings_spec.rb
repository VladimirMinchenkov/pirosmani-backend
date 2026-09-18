require 'rails_helper'

RSpec.describe "Admin::V1::AppSettings", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe 'GET /admin/v1/app_settings' do
    it 'returns all settings' do
      create(:app_setting, key: 'delivery_mode', value: 'yandex')
      create(:app_setting, key: 'max_order_price', value: '500')

      get '/admin/v1/app_settings', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(2)
    end
  end

  describe 'PATCH /admin/v1/app_settings/:id' do
    let(:setting) { create(:app_setting, key: 'delivery_mode', value: 'internal') }

    it 'updates the setting value' do
      patch "/admin/v1/app_settings/#{setting.id}",
            params: { app_setting: { value: 'yandex' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['value']).to eq('yandex')
    end
  end
end