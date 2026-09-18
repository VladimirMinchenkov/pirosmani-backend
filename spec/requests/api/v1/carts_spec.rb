require 'rails_helper'

RSpec.describe "Api::V1::Carts", type: :request do
  let(:menu_item) { create(:menu_item, price: 10.00) }
  let(:addon) { create(:addon, price: 1.50) }
  let(:client) { create(:client) }
  let(:client_headers) { { 'Authorization' => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }

  describe 'GET /api/v1/cart' do
    context 'for guest' do
      it 'creates a new cart with session_id' do
        get '/api/v1/cart'

        expect(response).to have_http_status(:ok)
        body = json_response
        expect(body['session_id']).to be_present
        expect(body['cart_items']).to be_empty
      end

      it 'returrns existing cart by session_id' do
        cart = create(:cart, :for_session)
        get '/api/v1/cart', headers: { 'X-Client-Session-Id' => cart.session_id }

        body = json_response
        expect(body['id']).to eq(cart.id)
      end
    end

    context 'for authenticated client' do
      it 'returrns client cart' do
        cart = create(:cart, :for_client, client: client)
        create(:cart_item, cart: cart, menu_item: menu_item)

        get '/api/v1/cart', headers: client_headers

        body = json_response
        expect(body['id']).to eq(cart.id)
        expect(body['cart_items'].size).to eq(1)
      end

      it 'creates cart if none exists' do
        get '/api/v1/cart', headers: client_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['cart_items']).to be_empty
      end
    end
  end

  describe 'PUT /api/v1/cart' do
    let(:cart) { create(:cart, :for_session) }
    let(:session_headers) { { 'X-Client-Session-Id' => cart.session_id } }

    it 'repllaces all cart items' do
      put '/api/v1/cart',
          params: {
            cart_items: [
              { menu_item_id: menu_item.id, quantity: 2, addon_ids: [addon.id] }
            ]
          },
          headers: session_headers

      body = json_response
      expect(body['cart_items'].size).to eq(1)
      expect(body['cart_items'].first['quantity']).to eq(2)
      expect(body['cart_items'].first['addons'].size).to eq(1)
    end
  end

  describe 'DELETE /api/v1/cart' do
    let(:cart) { create(:cart, :for_session) }
    let(:session_headers) { { 'X-Client-Session-Id' => cart.session_id } }

    it 'cllears all cart items' do
      create(:cart_item, cart: cart, menu_item: menu_item)

      delete '/api/v1/cart', headers: session_headers

      body = json_response
      expect(body['cart_items']).to be_empty
    end
  end
end
