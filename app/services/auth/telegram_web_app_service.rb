# app/services/auth/telegram_web_app_service.rb
#
# Проверяет initData, полученный от Telegram Mini App
# (см. plans/telegram-mini-app-plan.md, раздел 1.2), и находит/создаёт
# соответствующего Client. Алгоритм проверки HMAC-подписи — стандартный
# для Telegram Mini Apps:
# https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
#
# ВАЖНО (см. ревью в plans/telegram-mini-app-deepseek-prompt.md, раздел
# "Ревью реализации DeepSeek"): исходный план ошибочно предполагал, что номер
# телефона появляется прямо внутри initData после вызова Telegram.requestContact().
# В реальности Telegram возвращает телефон как ОТДЕЛЬНЫЙ подписанный объект
# (RequestedContact: { contact: {...}, auth_date, hash }) — НЕ модифицируя
# initData. Поэтому для привязки телефона нужна отдельная проверка подписи
# этого объекта — см. .verify_contact!.
module Auth
  class TelegramWebAppService
    # Telegram сам рекомендует отклонять initData старше суток — иначе
    # перехваченная строка (например, из логов реверс-прокси) может быть
    # переиграна повторно для получения JWT от чужого имени.
    MAX_AUTH_AGE = 24.hours

    # Возвращает найденного/созданного Client, либо nil, если подпись
    # невалидна, отсутствует, либо initData устарела.
    def self.verify!(init_data_raw)
      new(init_data_raw).verify!
    end

    # Проверяет подпись объекта RequestedContact, полученного фронтендом от
    # Telegram.WebApp.requestContact() (см. @telegram-apps/sdk requestContact()).
    # Использует ТОТ ЖЕ секретный ключ и алгоритм, что и initData — Telegram
    # подписывает все WebApp-payload'ы одним и тем же HMAC-SHA256("WebAppData").
    #
    # Возвращает номер телефона (String), если подпись валидна, свежая и
    # user_id внутри contact совпадает с ожидаемым (защита от подмены телефона
    # чужого пользователя) — иначе nil.
    def self.verify_contact!(contact_data_raw, expected_telegram_user_id:)
      new(contact_data_raw).verify_contact!(expected_telegram_user_id: expected_telegram_user_id)
    end

    def initialize(init_data_raw)
      @init_data_raw = init_data_raw
    end

    def verify!
      return nil if @init_data_raw.blank?

      params = parse_params
      return nil unless params

      received_hash = params.delete("hash")
      return nil if received_hash.blank?

      return nil unless valid_signature?(params, received_hash)
      return nil unless fresh?(params)

      find_or_create_client(params)
    end

    def verify_contact!(expected_telegram_user_id:)
      return nil if @init_data_raw.blank?

      params = parse_params
      return nil unless params

      received_hash = params.delete("hash")
      return nil if received_hash.blank?

      return nil unless valid_signature?(params, received_hash)
      return nil unless fresh?(params)

      contact_json = params["contact"]
      return nil if contact_json.blank?

      contact = JSON.parse(contact_json)
      return nil unless contact["user_id"].to_i == expected_telegram_user_id.to_i

      contact["phone_number"].presence
    rescue JSON::ParserError
      nil
    end

    private

    def parse_params
      URI.decode_www_form(@init_data_raw).to_h
    rescue ArgumentError
      nil
    end

    def valid_signature?(params, received_hash)
      data_check_string = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
      secret_key = OpenSSL::HMAC.digest("SHA256", bot_token, "WebAppData")
      computed_hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)

      ActiveSupport::SecurityUtils.secure_compare(computed_hash, received_hash)
    end

    def fresh?(params)
      auth_date = Time.at(params["auth_date"].to_i)
      auth_date >= MAX_AUTH_AGE.ago
    rescue
      false
    end

    # Ищем по telegram_user_id (основной случай), а если не найден — по
    # совпадающему номеру телефона (если Telegram передал phone через
    # requestContact). Это предотвращает создание ДУБЛИКАТА Client для
    # человека, который уже был клиентом через обычный телефон+OTP на
    # pirosmani-frontend (иначе получим два разных клиента с раздельной
    # историей заказов и бонусами на одного физического человека).
    def find_or_create_client(params)
      user_id = params["id"].to_i
      phone = params["phone"].presence

      client = Client.find_by(telegram_user_id: user_id)
      client ||= Client.find_by(phone: phone) if phone.present?

      if client
        client.update!(
          telegram_user_id: user_id,
          telegram_username: params["username"],
          telegram_first_name: params["first_name"]
        )
      else
        client = Client.create!(
          telegram_user_id: user_id,
          telegram_username: params["username"],
          telegram_first_name: params["first_name"],
          name: params["first_name"].presence || "Гость",
          phone: phone
        )
      end

      client
    end

    def bot_token
      Rails.application.credentials.dig(:telegram, :pirosmani_brest_delivery_bot_token)
    end
  end
end
