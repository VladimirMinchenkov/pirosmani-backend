module Api
  module V1
    class BaseController < ActionController::API
      before_action :set_current_client

      private

      def set_current_client
        @current_client = nil

        auth_header = request.headers['Authorization']
        if auth_header&.start_with?('Bearer ')
          token = auth_header.split(' ').last
          @current_client = Client.find_by(access_token: token)
        end

        unless @current_client.present?
          session_id = cookies[:client_session_id] || request.headers['X-Client-Session-Id']
          cart = Cart.find_by(session_id: session_id) if session_id.present?
          @current_client = cart&.client if cart.present?
        end
      end

      def current_client
        @current_client
      end
    end
  end
end
