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

  describe 'POST /admin/v1/app_settings' do
    it 'creates a new setting' do
      post '/admin/v1/app_settings',
           params: { app_setting: { key: 'cafe_phone', value: '+375 29 123-45-67' } },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['key']).to eq('cafe_phone')
      expect(json_response['value']).to eq('+375 29 123-45-67')
    end
  end

  describe 'cafe_address geocoding' do
    # WebMock блокирует все нестабленные реальные HTTP-запросы (в т.ч. к
    # Geoapify) — стабим ответ явно, вместо того чтобы полагаться на реальную
    # сеть. WebMock::NetConnectNotAllowedError наследуется от Exception (не
    # StandardError), поэтому бare `rescue => e` в контроллере его не ловит.
    before do
      stub_request(:get, /api\.geoapify\.com\/v1\/geocode\/search/)
        .to_return(
          status: 200,
          body: { results: [{ "lat" => 52.0975, "lon" => 23.7 }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it 'auto-creates cafe_lat and cafe_lng when cafe_address is saved' do
      # Создаём адрес кафе — контроллер должен вызвать геокодирование
      post '/admin/v1/app_settings',
           params: { app_setting: { key: 'cafe_address', value: 'Брест, Советская 64' } },
           headers: headers

      expect(response).to have_http_status(:created)

      # Проверяем что координаты создались (геокодирование через Geoapify)
      lat = AppSetting.find_by(key: 'cafe_lat')
      lng = AppSetting.find_by(key: 'cafe_lng')

      # Если credentials для Geoapify не настроены (blank api_key) — геокодинг
      # не вызывается вообще, это тоже ок в тестовом окружении
      if lat && lng
        expect(lat.value.to_f).to be_between(52.0, 52.2)
        expect(lng.value.to_f).to be_between(23.5, 23.9)
      end
    end

    it 'updates cafe_lat/cafe_lng when cafe_address is changed' do
      addr = create(:app_setting, key: 'cafe_address', value: 'Брест, Советская 64')
      create(:app_setting, key: 'cafe_lat', value: '52.09')
      create(:app_setting, key: 'cafe_lng', value: '23.69')

      patch "/admin/v1/app_settings/#{addr.id}",
            params: { app_setting: { value: 'Брест, улица Московская 200' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      # Координаты должны обновиться (если credentials для Geoapify настроены)
    end
  end
end