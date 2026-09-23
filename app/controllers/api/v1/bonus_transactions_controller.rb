module Api
  module V1
    class BonusTransactionsController < BaseController
      before_action :require_client!

      # GET /api/v1/bonus_transactions
      def index
        transactions = current_client.bonus_transactions
                                     .recent
                                     .limit(50)

        render json: {
          bonus_points: current_client.bonus_points,
          transactions: transactions.map { |t| serialize_transaction(t) }
        }
      end

      private

      def require_client!
        return if current_client.present?
        render json: { error: "Authorization required" }, status: :unauthorized
      end

      def serialize_transaction(t)
        {
          id: t.id,
          kind: t.kind,
          amount: t.amount,
          description: t.description,
          order_id: t.order_id,
          created_at: t.created_at.iso8601
        }
      end
    end
  end
end
