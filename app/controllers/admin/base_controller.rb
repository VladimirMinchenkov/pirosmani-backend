# app/controllers/admin/base_controller.rb
module Admin
  class BaseController < ActionController::API
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      # Ищем заголовок Authorization: Bearer <token>
      auth_header = request.headers['Authorization']
      return render json: { error: 'Missing authorization header' }, status: :unauthorized unless auth_header

      token = auth_header.split(' ').last
      return render json: { error: 'Invalid token format' }, status: :unauthorized unless token

      # Находим админа по токену (обычно это поле в таблице admins, например `access_token`)
      @current_admin = Admin.find_by(access_token: token)

      if @current_admin.nil?
        render json: { error: 'Invalid or expired admin token' }, status: :unauthorized
      end
    end

    # Опционально: можно добавить проверку прав, если у админов будут роли
    # def authorize_role!(required_role)
    #   render json: { error: 'Insufficient permissions' }, status: :forbidden unless @current_admin.role == required_role
    # end
  end
end
