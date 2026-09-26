require 'rails_helper'

RSpec.describe "Api::V1::TelegramSessions", type: :request do
  let(:bot_token) { "test-bot-token" }

  before do
    allow(Rails.application.credentials).to receive(:dig)
      .with(:telegram, :pirosmani_brest_delivery_bot_token)
      .and_return(bot_token)
  end

  def build_init_data(params)
    data_check_string = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
    secret_key = OpenSSL::HMAC.digest("SHA256", bot_token, "WebAppData")
    hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)

    URI.encode_www_form(params.merge("hash" => hash))
  end

  describe "POST /api/v1/telegram_sessions" do
    it "возвращает 400, если init_data отсутствует" do
      post "/api/v1/telegram_sessions", params: {}

      expect(response).to have_http_status(:bad_request)
    end

    it "возвращает 401 при невалидной подписи" do
      post "/api/v1/telegram_sessions", params: { init_data: "id=1&hash=invalid" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "создаёт клиента и возвращает JWT-пару при валидной подписи" do
      init_data = build_init_data({
        "id" => "555",
        "first_name" => "Нино",
        "auth_date" => Time.current.to_i.to_s
      })

      post "/api/v1/telegram_sessions", params: { init_data: init_data }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["access_token"]).to be_present
      expect(json["refresh_token"]).to be_present
      expect(json["client"]["name"]).to eq("Нино")
      expect(json["client"]["has_phone"]).to eq(false)

      expect(Client.find_by(telegram_user_id: 555)).to be_present
    end

    it "выданный access_token проходит аутентификацию в других api/v1 эндпоинтах" do
      init_data = build_init_data({ "id" => "777", "auth_date" => Time.current.to_i.to_s })
      post "/api/v1/telegram_sessions", params: { init_data: init_data }
      token = JSON.parse(response.body)["access_token"]

      get "/api/v1/orders", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
    end

    def build_contact_data(user_id:, phone:)
      contact_json = { "user_id" => user_id, "phone_number" => phone, "first_name" => "Тест" }.to_json
      params = { "contact" => contact_json, "auth_date" => Time.current.to_i.to_s }
      data_check_string = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
      secret_key = OpenSSL::HMAC.digest("SHA256", bot_token, "WebAppData")
      hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)

      URI.encode_www_form(params.merge("hash" => hash))
    end

    it "привязывает телефон к клиенту при валидном contact_data (поток requestContact)" do
      init_data = build_init_data({ "id" => "888", "auth_date" => Time.current.to_i.to_s })
      contact_data = build_contact_data(user_id: 888, phone: "+375291112233")

      post "/api/v1/telegram_sessions", params: { init_data: init_data, contact_data: contact_data }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["client"]["has_phone"]).to eq(true)
      expect(json["client"]["phone"]).to eq("+375291112233")
    end

    it "игнорирует contact_data с чужим user_id (защита от подмены телефона)" do
      init_data = build_init_data({ "id" => "999", "auth_date" => Time.current.to_i.to_s })
      contact_data = build_contact_data(user_id: 111, phone: "+375291112233")

      post "/api/v1/telegram_sessions", params: { init_data: init_data, contact_data: contact_data }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["client"]["has_phone"]).to eq(false)
    end

    it "связывает telegram-клиента с существующим Client по телефону из contact_data, а не создаёт дубликат" do
      existing = create(:client, phone: "+375291112233")
      init_data = build_init_data({ "id" => "1010", "auth_date" => Time.current.to_i.to_s })
      contact_data = build_contact_data(user_id: 1010, phone: "+375291112233")

      expect {
        post "/api/v1/telegram_sessions", params: { init_data: init_data, contact_data: contact_data }
      }.not_to change(Client, :count)

      json = JSON.parse(response.body)
      expect(json["client"]["id"]).to eq(existing.id)
      expect(json["client"]["has_phone"]).to eq(true)
    end
  end
end
