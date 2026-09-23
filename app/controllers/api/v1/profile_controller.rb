module Api
  module V1
    class ProfileController < BaseController
      before_action :require_client!

      # GET /api/v1/profile
      def show
        render json: {
          id: current_client.id,
          phone: current_client.phone,
          name: current_client.name,
          bonus_points: current_client.bonus_points,
          created_at: current_client.created_at.iso8601
        }
      end

      private

      def require_client!
        return if current_client.present?
        render json: { error: "Authorization required" }, status: :unauthorized
      end
    end
  end
end
