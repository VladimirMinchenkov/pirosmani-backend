# app/controllers/api/v1/sessions_controller.rb
module Api
  module V1
    class SessionsController < BaseController
      def create
        phone = params[:phone]

        # TODO (Фаза C, следующий шаг): проверка кода из PhoneVerification вместо доверия к номеру.
        client = Client.find_by(phone: phone) || Client.create!(phone: phone, name: "Гость")

        # Если есть активная гостевая корзина по session_id — привязываем к клиенту
        session_id = request.headers["X-Client-Session-Id"] || params[:session_id]
        if session_id.present?
          cart = Cart.find_by(session_id: session_id)
          if cart && cart.client_id.nil?
            cart.update!(client: client)
          end
        end

        session = Auth::IssueClientSession.call(client)
        render json: session_payload(session), status: :created
      end

      def refresh
        raw_token = params[:refresh_token]
        return render json: { error: "refresh_token is required" }, status: :bad_request if raw_token.blank?

        record = RefreshToken.active.find_by(token: RefreshToken.hash_token(raw_token))
        return render json: { error: "Invalid or expired refresh token" }, status: :unauthorized unless record

        record.revoke!
        session = Auth::IssueClientSession.call(record.client)

        render json: session_payload(session), status: :ok
      end

      def destroy
        raw_token = params[:refresh_token] || request.headers["X-Refresh-Token"]
        if raw_token.present?
          record = RefreshToken.active.find_by(token: RefreshToken.hash_token(raw_token))
          record&.revoke!
        end

        head :no_content
      end

      private

      def session_payload(session)
        {
          access_token: session[:access_token],
          refresh_token: session[:refresh_token],
          client: {
            id: session[:client].id,
            phone: session[:client].phone,
            name: session[:client].name
          }
        }
      end
    end
  end
end
