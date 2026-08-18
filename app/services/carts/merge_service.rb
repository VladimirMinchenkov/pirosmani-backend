# app/services/carts/merge_service.rb
module Carts
  class MergeService
    def initialize(guest_cart:, client_cart:)
      @guest_cart = guest_cart
      @client_cart = client_cart
    end

    def call
      return client_cart if guest_cart.blank?

      ActiveRecord::Base.transaction do
        guest_cart.cart_items.each do |item|
          existing_item = client_cart.cart_items.find_by(product_id: item.product_id)

          if existing_item
            existing_item.update!(quantity: existing_item.quantity + item.quantity)
          else
            client_cart.cart_items.create!(product_id: item.product_id, quantity: item.quantity)
          end
        end

        guest_cart.destroy!
      end

      client_cart
    end

    private

    attr_reader :guest_cart, :client_cart
  end
end