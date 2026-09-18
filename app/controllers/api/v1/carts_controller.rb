module Api
  module V1
    class CartsController < BaseController
      def show
        # Получаем session_id из заголовка
        session_id = request.headers['X-Client-Session-Id']
        
        # Если клиент залогинен (есть токен), ищем по клиенту
        if current_client.present?
          cart = Cart.find_or_create_by(client: current_client)
        else
          # Если гость — ищем по session_id
          if session_id.blank?
            # Если нет ни токена, ни session_id — создаём новую пустую корзину для гостя
            cart = Cart.create!(session_id: SecureRandom.hex(8))
            return render json: cart, status: :created # Возвращаем новый session_id фронтенду
          end
          cart = Cart.find_or_create_by(session_id: session_id)
        end
        
        render json: cart
      end
      
      def update
        # ... логика добавления товаров ...
      end
    end
  end
end

