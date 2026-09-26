# app/controllers/api/v1/telegram_sessions_controller.rb
#
# Аутентификация для pirosmani-telegram-app (Telegram Mini App) — принимает
# сырую строку initData от Telegram.WebApp.initDataRaw, проверяет HMAC-подпись
# и выдаёт ту же JWT-пару, что и обычная телефон+OTP аутентификация (см.
# Api::V1::SessionsController). См. plans/telegram-mini-app-plan.md, раздел 1.3.
module Api
  module V1
    class TelegramSessionsController < BaseController
      def create
        init_data = params[:init_data]
        return render json: { error: "init_data is required" }, status: :bad_request if init_data.blank?

        client = Auth::TelegramWebAppService.verify!(init_data)
        return render json: { error: "Invalid init_data signature" }, status: :unauthorized unless client

        client = link_phone_from_contact(client, params[:contact_data]) if params[:contact_data].present?

        session = Auth::IssueClientSession.call(client)
        render json: session_payload(session), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      # Привязывает номер телефона, полученный через Telegram.WebApp.requestContact(),
      # к уже аутентифицированному client. contact_data — отдельный подписанный
      # payload (НЕ часть init_data, см. Auth::TelegramWebAppService.verify_contact!)
      # с собственным hash — обязательно проверяется независимо, иначе фронтенд
      # мог бы прислать произвольный номер телефона от имени чужого пользователя.
      #
      # Если номер уже принадлежит ДРУГОМУ существующему Client (человек уже
      # был клиентом через обычный телефон+OTP на pirosmani-frontend) —
      # переносим telegram_user_id на этот существующий аккаунт вместо
      # создания дубликата с раздельной историей заказов/бонусов (см. раздел
      # "Открытые вопросы", пункт 3 в plans/telegram-mini-app-plan.md).
      # Перенос делаем только если у текущего (только что созданного) client
      # ещё нет заказов/бонусов — иначе безопаснее оставить оба аккаунта
      # раздельно и залогировать конфликт для ручной проверки, чем молча
      # обнулить telegram_user_id у аккаунта с историей.
      def link_phone_from_contact(client, contact_data)
        phone = Auth::TelegramWebAppService.verify_contact!(
          contact_data, expected_telegram_user_id: client.telegram_user_id
        )
        return client if phone.blank?

        existing = Client.find_by(phone: phone)

        if existing && existing.id != client.id
          if client.orders.none? && client.bonus_transactions.none?
            telegram_user_id = client.telegram_user_id
            telegram_username = client.telegram_username
            telegram_first_name = client.telegram_first_name

            # client — временная запись без заказов/бонусов (создана только что
            # при первом входе через Telegram, до привязки телефона). Раз мы
            # переносим её identity на existing — саму запись удаляем, а не
            # просто обнуляем telegram_user_id, чтобы не копить в базе
            # "осиротевшие" Client без единого идентификатора (ни phone, ни
            # telegram_user_id).
            client.destroy!
            existing.update!(
              telegram_user_id: telegram_user_id,
              telegram_username: telegram_username,
              telegram_first_name: telegram_first_name
            )
            existing
          else
            Rails.logger.warn(
              "[TelegramSessionsController] Конфликт привязки телефона #{phone}: " \
              "client##{client.id} (telegram_user_id=#{client.telegram_user_id}) уже имеет " \
              "заказы/бонусы, но телефон занят client##{existing.id}. Оставляю раздельно."
            )
            client
          end
        elsif client.phone.blank?
          client.update!(phone: phone)
          client
        else
          client
        end
      end

      def session_payload(session)
        {
          access_token: session[:access_token],
          refresh_token: session[:refresh_token],
          client: {
            id: session[:client].id,
            phone: session[:client].phone,
            name: session[:client].name,
            has_phone: session[:client].phone.present?
          }
        }
      end
    end
  end
end
