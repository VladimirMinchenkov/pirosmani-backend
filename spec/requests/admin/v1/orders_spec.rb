require 'rails_helper'

RSpec.describe "Admin::V1::Orders", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe 'GET /admin/v1/orders' do
    it 'returns all orders' do
      create(:order, :with_items)
      create(:order, :pickup)

      get '/admin/v1/orders', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(2)
    end
  end

  describe 'GET /admin/v1/orders/:id' do
    let(:order) { create(:order, :with_items) }

    it 'returns the order with items' do
      get "/admin/v1/orders/#{order.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('pending')
      expect(json_response['order_items']).not_to be_empty
    end
  end

  describe 'PATCH /admin/v1/orders/:id' do
    let(:order) { create(:order) }

    it 'updates the order status' do
      patch "/admin/v1/orders/#{order.id}",
            params: { order: { status: 'confirmed' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('confirmed')
    end
  end
end
