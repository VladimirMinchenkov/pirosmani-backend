# spec/services/carts/merge_service_spec.rb
require 'rails_helper'

RSpec.describe Carts::MergeService do
  describe '#call' do
    let(:client) { create(:client) }
    let(:client_cart) { create(:cart, :for_client, client: client) }
    let(:guest_cart) { create(:cart) }
    let(:product) { create(:product) }

    subject { described_class.new(guest_cart: guest_cart, client_cart: client_cart).call }

    context "когда товара нет в корзине клиента" do
      let!(:guest_item) { create(:cart_item, cart: guest_cart, product: product, quantity: 2) }

      it "переносит товар в корзину клиента" do
        subject
        expect(client_cart.cart_items.find_by(product: product).quantity).to eq(2)
      end
    end

    context "когда товар уже есть в корзине клиента" do
      let!(:client_item) { create(:cart_item, cart: client_cart, product: product, quantity: 1) }
      let!(:guest_item) { create(:cart_item, cart: guest_cart, product: product, quantity: 2) }

      it "суммирует количество" do
        subject
        expect(client_cart.cart_items.find_by(product: product).quantity).to eq(3)
      end
    end

    context "удаляет гостевую корзину" do
      let!(:guest_item) { create(:cart_item, cart: guest_cart, product: product, quantity: 1) }

      it "удаляет гостевую корзину после мерджа" do
        subject
        expect(Cart.exists?(guest_cart.id)).to be false
      end
    end

    context "когда гостевой корзины нет" do
      let(:guest_cart) { nil }

      it "возвращает корзину клиента без изменений" do
        expect(subject).to eq(client_cart)
      end
    end
  end
end