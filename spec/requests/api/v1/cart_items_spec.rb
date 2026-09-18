require 'rails_helper'

RSpec.describe "Api::V1::CartItems", type: :request do
  let(:menu_item) { create(:menu_item, price: 10.00) }
  let(:addon) { create(:addon, price: 1.50) }
  let(:client) { create(:client) }
  let(:client_headers) { { 'Authorization' => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let(:guest_headers) { { 'X-Client-Session-Id' => SecureRandom.hex(8) } }

  describe 'POST /api/v1/cart_items (guest)' do
    it 'creates a cart item for guest user' do
      post '/api/v1/cart_items',
           params: { menu_item_id: menu_item.id, quantity: 2 },
           headers: guest_headers

      expect(response).to have_http_status(:created)
      body = json_response
      expect(body['cart_items'].size).to eq(1)
      expect(body['cart_items'].first['quantity']).to eq(2)
    end

    it 'creates a cart item with addons' do
      post '/api/v1/cart_items',
           params: { menu_item_id: menu_item.id, quantity: 1, addon_ids: [addon.id] },
           headers: guest_headers

      expect(response).to have_http_status(:created)
      body = json_response
      expect(body['cart_items'].first['addons'].size).to eq(1)
    end

    it 'increments quantity when same item added again' do
      post '/api/v1/cart_items',
           params: { menu_item_id: menu_item.id, quantity: 2 },
           headers: guest_headers

      post '/api/v1/cart_items',
           params: { menu_item_id: menu_item.id, quantity: 3 },
           headers: guest_headers

      body = json_response
      expect(body['cart_items'].first['quantity']).to eq(5)
    end

    it 'returns 400 without session id' do
      post '/api/v1/cart_items',
           params: { menu_item_id: menu_item.id, quantity: 1 }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /api/v1/cart_items (client)' do
    it 'creates a cart item for authenticated client' do
      post '/api/v1/cart_items',
           params: { menu_item_id: menu_item.id, quantity: 1 },
           headers: client_headers

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/v1/cart_items/:id' do
    let(:cart) { create(:cart, :for_session) }
    let(:cart_item) { create(:cart_item, cart: cart, menu_item: menu_item, quantity: 2) }
    let(:session_headers) { { 'X-Client-Session-Id' => cart.session_id } }

    it 'updates quantity' do
      patch "/api/v1/cart_items/#{cart_item.id}",
            params: { quantity: 5 },
            headers: session_headers

      body = json_response
      expect(body['cart_items'].first['quantity']).to eq(5)
    end

    it 'removes item when quantity is 0' do
      patch "/api/v1/cart_items/#{cart_item.id}",
            params: { quantity: 0 },
            headers: session_headers

      body = json_response
      expect(body['cart_items']).to be_empty
    end

    it 'syncs addons on update' do
      new_addon = create(:addon, name: 'Bacon', price: 3.00)
      patch "/api/v1/cart_items/#{cart_item.id}",
            params: { quantity: 1, addon_ids: [new_addon.id] },
            headers: session_headers

      body = json_response
      expect(body['cart_items'].first['addons'].size).to eq(1)
      expect(body['cart_items'].first['addons'].first['name']).to eq('Bacon')
    end
  end

  describe 'DELETE /api/v1/cart_items/:id' do
    let(:cart) { create(:cart, :for_session) }
    let(:cart_item) { create(:cart_item, cart: cart, menu_item: menu_item) }
    let(:session_headers) { { 'X-Client-Session-Id' => cart.session_id } }

    it 'deletes the cart item' do
      delete "/api/v1/cart_items/#{cart_item.id}", headers: session_headers

      body = json_response
      expect(body['cart_items']).to be_empty
    end
  end
end
