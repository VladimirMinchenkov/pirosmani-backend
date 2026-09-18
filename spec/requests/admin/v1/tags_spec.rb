require 'rails_helper'

RSpec.describe "Admin::V1::Tags", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe 'GET /admin/v1/tags' do
    it 'returns all tags' do
      create(:tag, name: 'Spicy')
      create(:tag, name: 'Vegan')

      get '/admin/v1/tags', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(2)
    end
  end

  describe 'POST /admin/v1/tags' do
    it 'creates a tag' do
      post '/admin/v1/tags',
           params: { tag: { name: 'New Tag' } },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('New Tag')
    end
  end

  describe 'PATCH /admin/v1/tags/:id' do
    let(:tag) { create(:tag) }

    it 'updates the tag' do
      patch "/admin/v1/tags/#{tag.id}",
            params: { tag: { name: 'Updated Tag' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Tag')
    end
  end

  describe 'DELETE /admin/v1/tags/:id' do
    let(:tag) { create(:tag) }

    it 'deletes the tag' do
      delete "/admin/v1/tags/#{tag.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Tag.exists?(tag.id)).to be false
    end
  end
end