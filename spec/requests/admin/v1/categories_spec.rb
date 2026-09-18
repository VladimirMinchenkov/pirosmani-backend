require 'rails_helper'

RSpec.describe "Admin::V1::Categories", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe 'GET /admin/v1/categories' do
    it 'returns all categories ordered by position' do
      create(:category, name: 'Second', position: 2)
      create(:category, name: 'First', position: 1)

      get '/admin/v1/categories', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(2)
      expect(json_response.first['name']).to eq('First')
    end

    it 'returns 401 without auth' do
      get '/admin/v1/categories'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /admin/v1/categories/:id' do
    let(:category) { create(:category) }

    it 'returns the category' do
      get "/admin/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq(category.name)
    end

    it 'returns 404 for non-existent category' do
      get '/admin/v1/categories/0', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /admin/v1/categories' do
    it 'creates a category' do
      post '/admin/v1/categories',
           params: { category: { name: 'New Category', icon: '🍕', position: 1 } },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('New Category')
    end

    it 'returns 422 with invalid params' do
      post '/admin/v1/categories',
           params: { category: { name: '' } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /admin/v1/categories/:id' do
    let(:category) { create(:category) }

    it 'updates the category' do
      patch "/admin/v1/categories/#{category.id}",
            params: { category: { name: 'Updated' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated')
    end
  end

  describe 'DELETE /admin/v1/categories/:id' do
    let(:category) { create(:category) }

    it 'deletes the category' do
      delete "/admin/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Category.exists?(category.id)).to be false
    end
  end
end