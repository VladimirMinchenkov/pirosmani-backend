# app/controllers/api/v1/sessions_controller.rb
module Api
  module V1
    class SessionsController < BaseController
      def create
        phone = params[:phone]
        name = params[:name]

        # Тут должна быть проверка кода из SMS и т.п.
        # Для MVP допустим, что телефон уже верифицирован или мы его просто находим
        client = Client.find_by(phone: phone)

        client = Client.find_by(phone: phone) || Client.create!(phone: phone, name: 'Гость')

        # Если есть активная корзина по session_id — привязываем к клиенту
        session_id = cookies[:client_session_id] || request.headers['X-Client-Session-Id']
        if session_id.present?
          cart = Cart.find_by(session_id: session_id)
          if cart && cart.client_id.nil?
            cart.update!(client: client)
            # Опционально: очистить session_id, потому что теперь клиент залогинен
            # cart.update!(session_id: nil)
          end
        end

        client.update!(access_token: SecureRandom.urlsafe_base64(32))

        render json: {
          token: client.access_token,
          client: {
            id: client.id,
            phone: client.phone,
            name: client.name
          }
        }, status: :created
      end

      def destroy
        # Опционально: можно обнулять access_token при выходе
        if current_client
          current_client.update!(access_token: nil)
        end
        head :no_content
      end
    end
  end
end
