# app/controllers/api/v1/client_addresses_controller.rb
module Api
  module V1
    class ClientAddressesController < BaseController
      before_action :require_client!
      before_action :set_client_address, only: [:update, :destroy]

      def index
        render json: current_client.client_addresses.map { |a| ClientAddressSerializer.new(a).as_json }
      end

      def create
        address = current_client.client_addresses.new(client_address_params)

        if address.save
          render json: ClientAddressSerializer.new(address).as_json, status: :created
        else
          render json: { errors: address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @client_address.update(client_address_params)
          render json: ClientAddressSerializer.new(@client_address).as_json
        else
          render json: { errors: @client_address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @client_address.destroy
        head :no_content
      end

      private

      def require_client!
        return if current_client.present?

        render json: { error: "Authorization required" }, status: :unauthorized
      end

      def set_client_address
        @client_address = current_client.client_addresses.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Address not found" }, status: :not_found
      end

      def client_address_params
        params.require(:client_address).permit(
          :label, :emoji, :street, :entrance, :apt, :floor, :intercom, :lat, :lng
        )
      end
    end
  end
end
