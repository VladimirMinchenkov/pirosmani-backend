require 'rails_helper'

RSpec.describe Auth::TelegramWebAppService do
  let(:bot_token) { "test-bot-token" }

  before do
    allow(Rails.application.credentials).to receive(:dig)
      .with(:telegram, :pirosmani_brest_delivery_bot_token)
      .and_return(bot_token)
  end

  # Строит валидную (подписанную) init_data строку так же, как это делает
  # реальный Telegram-клиент — по тому же алгоритму, который проверяет сервис.
  def build_init_data(params, token: bot_token)
    data_check_string = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
    secret_key = OpenSSL::HMAC.digest("SHA256", token, "WebAppData")
    hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)

    URI.encode_www_form(params.merge("hash" => hash))
  end

  describe ".verify!" do
    it "возвращает nil, если init_data пустая" do
      expect(described_class.verify!("")).to be_nil
      expect(described_class.verify!(nil)).to be_nil
    end

    it "возвращает nil при неверной подписи (подделанные данные)" do
      init_data = build_init_data({ "id" => "12345", "auth_date" => Time.current.to_i.to_s }, token: "wrong-token")
      expect(described_class.verify!(init_data)).to be_nil
    end

    it "возвращает nil, если auth_date старше 24 часов (защита от replay-атак)" do
      init_data = build_init_data({ "id" => "12345", "auth_date" => 25.hours.ago.to_i.to_s })
      expect(described_class.verify!(init_data)).to be_nil
    end

    it "создаёт нового Client при валидной подписи и свежем auth_date" do
      init_data = build_init_data({
        "id" => "999888777",
        "first_name" => "Вахтанг",
        "username" => "vakhtang_tg",
        "auth_date" => Time.current.to_i.to_s
      })

      expect { described_class.verify!(init_data) }.to change(Client, :count).by(1)

      client = described_class.verify!(init_data)
      expect(client.telegram_user_id).to eq(999888777)
      expect(client.telegram_username).to eq("vakhtang_tg")
      expect(client.name).to eq("Вахтанг")
      expect(client.phone).to be_nil
    end

    it "находит существующего Client по telegram_user_id при повторном вызове" do
      init_data = build_init_data({ "id" => "111", "auth_date" => Time.current.to_i.to_s })

      first_client = described_class.verify!(init_data)
      second_client = described_class.verify!(init_data)

      expect(second_client.id).to eq(first_client.id)
    end

    it "связывает с существующим Client по номеру телефона, а не создаёт дубликат" do
      existing = create(:client, phone: "+375291112233")

      init_data = build_init_data({
        "id" => "222",
        "phone" => "+375291112233",
        "auth_date" => Time.current.to_i.to_s
      })

      expect { described_class.verify!(init_data) }.not_to change(Client, :count)

      client = described_class.verify!(init_data)
      expect(client.id).to eq(existing.id)
      expect(client.telegram_user_id).to eq(222)
    end
  end

  describe ".verify_contact!" do
    def build_contact_data(user_id:, phone:, auth_date: Time.current.to_i.to_s, token: bot_token)
      contact_json = { "user_id" => user_id, "phone_number" => phone, "first_name" => "Вахтанг" }.to_json
      params = { "contact" => contact_json, "auth_date" => auth_date }
      data_check_string = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
      secret_key = OpenSSL::HMAC.digest("SHA256", token, "WebAppData")
      hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)

      URI.encode_www_form(params.merge("hash" => hash))
    end

    it "возвращает номер телефона при валидной подписи и совпадающем user_id" do
      contact_data = build_contact_data(user_id: 999888777, phone: "+375291112233")

      phone = described_class.verify_contact!(contact_data, expected_telegram_user_id: 999888777)

      expect(phone).to eq("+375291112233")
    end

    it "возвращает nil при неверной подписи (подделанные данные)" do
      contact_data = build_contact_data(user_id: 999888777, phone: "+375291112233", token: "wrong-token")

      phone = described_class.verify_contact!(contact_data, expected_telegram_user_id: 999888777)

      expect(phone).to be_nil
    end

    it "возвращает nil, если user_id в contact не совпадает с ожидаемым (защита от подмены телефона чужого пользователя)" do
      contact_data = build_contact_data(user_id: 999888777, phone: "+375291112233")

      phone = described_class.verify_contact!(contact_data, expected_telegram_user_id: 111222333)

      expect(phone).to be_nil
    end

    it "возвращает nil, если auth_date старше 24 часов" do
      contact_data = build_contact_data(user_id: 999888777, phone: "+375291112233", auth_date: 25.hours.ago.to_i.to_s)

      phone = described_class.verify_contact!(contact_data, expected_telegram_user_id: 999888777)

      expect(phone).to be_nil
    end

    it "возвращает nil для пустой строки" do
      expect(described_class.verify_contact!("", expected_telegram_user_id: 1)).to be_nil
      expect(described_class.verify_contact!(nil, expected_telegram_user_id: 1)).to be_nil
    end
  end
end
