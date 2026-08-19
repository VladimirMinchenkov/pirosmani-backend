module Admin
  module V1
    class SessionsController < ActionController::API
      def create
        admin = Admin.find_by(email: params[:email])
        if admin && admin.authenticate(params[:password])
          # тут можно сохранить токен в Redis/БД и вернуть клиенту
          render json: { token: admin.access_token, admin: { id: admin.id, email: admin.email } }
        else
          render json: { error: 'Invalid credentials' }, status: :unauthorized
        end
      end
    end
  end
end

