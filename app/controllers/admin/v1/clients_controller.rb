module Admin
  module V1
    class ClientsController < Admin::BaseController
      before_action :set_client, only: [:show, :update, :destroy]

      def index
        clients = Client.includes(:orders).order(created_at: :desc)
        render json: clients.map { |c| ClientSerializer.new(c).as_json }
      end

      def show
        orders = @client.orders.includes(:order_items).order(created_at: :desc).map do |order|
          {
            id: order.id,
            status: order.status,
            total_price: order.total_price&.to_f,
            delivery_price: order.delivery_price&.to_f,
            created_at: order.created_at&.iso8601,
            order_type: order.order_type,
            address: order.client_address.present? ? {
              street: order.client_address.street,
              entrance: order.client_address.entrance,
              apt: order.client_address.apt,
              floor: order.client_address.floor
            } : nil,
            items: order.order_items.map { |oi|
              {
                id: oi.id,
                menu_item_id: oi.menu_item_id,
                name: oi.menu_item&.name || "Блюдо ##{oi.menu_item_id}",
                quantity: oi.quantity,
                price: oi.price&.to_f
              }
            }
          }
        end
        render json: {
          client: ClientSerializer.new(@client).as_json,
          orders: orders,
          addresses: @client.client_addresses.map { |a| ClientAddressSerializer.new(a).as_json }
        }
      end

      def create
        client = Client.new(client_params)
        if client.save
          render json: ClientSerializer.new(client).as_json, status: :created
        else
          render json: { errors: client.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @client.update(client_params)
          render json: ClientSerializer.new(@client).as_json
        else
          render json: { errors: @client.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @client.destroy
        head :no_content
      end

      private

      def set_client
        @client = Client.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Client not found" }, status: :not_found
      end

      def client_params
        params.require(:client).permit(:phone, :name, :bonus_points)
      end
    end
  end
end