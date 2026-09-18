require 'rails_helper'

RSpec.describe "Admin::V1::ProductGroups", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe 'GET /admin/v1/product_groups' do
    it 'returns all product groups' do
      create(:product_group, name: 'Pizza')
      create(:product_group, name: 'Drinks')

      get '/admin/v1/product_groups', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(2)
    end
  end

  describe 'POST /admin/v1/product_groups' do
    it 'creates a product group' do
      post '/admin/v1/product_groups',
           params: { product_group: { name: 'New Group' } },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('New Group')
    end
  end

  describe 'PATCH /admin/v1/product_groups/:id' do
    let(:group) { create(:product_group) }

    it 'updates the product group' do
      patch "/admin/v1/product_groups/#{group.id}",
            params: { product_group: { name: 'Updated Group' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Group')
    end
  end

  describe 'DELETE /admin/v1/product_groups/:id' do
    let(:group) { create(:product_group) }

    it 'deletes the product group' do
      delete "/admin/v1/product_groups/#{group.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(ProductGroup.exists?(group.id)).to be false
    end
  end
end