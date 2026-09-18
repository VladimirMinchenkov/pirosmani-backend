require 'rails_helper'

RSpec.describe "Admin::V1::MenuItems", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }
  let(:category) { create(:category) }
  let(:product_group) { create(:product_group) }

  describe 'GET /admin/v1/menu_items' do
    it 'returns all menu items with includes' do
      create(:menu_item, name: 'Pizza', category: category, product_group: product_group)
      create(:menu_item, name: 'Burger', category: category, product_group: product_group)

      get '/admin/v1/menu_items', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(2)
    end
  end

  describe 'GET /admin/v1/menu_items/:id' do
    let(:item) { create(:menu_item, :with_tags, :with_addon_groups) }

    it 'returns the menu item with associations' do
      get "/admin/v1/menu_items/#{item.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq(item.name)
      expect(json_response['tags']).not_to be_empty
      expect(json_response['addon_groups']).not_to be_empty
    end
  end

  describe 'POST /admin/v1/menu_items' do
    let(:tag) { create(:tag) }
    let(:addon_group) { create(:addon_group) }

    it 'creates a menu item with tags and addon groups' do
      post '/admin/v1/menu_items',
           params: {
             menu_item: {
               name: 'New Pizza',
               price: 12.99,
               category_id: category.id,
               product_group_id: product_group.id,
               display_mode: 'simple',
               tag_ids: [tag.id],
               addon_group_ids: [addon_group.id]
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('New Pizza')
      expect(json_response['tags'].size).to eq(1)
      expect(json_response['addon_groups'].size).to eq(1)
    end

    it 'returns 422 with invalid params' do
      post '/admin/v1/menu_items',
           params: { menu_item: { name: '' } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /admin/v1/menu_items/:id' do
    let(:item) { create(:menu_item) }
    let(:new_tag) { create(:tag, name: 'New Tag') }

    it 'updates the menu item and replaces tags' do
      patch "/admin/v1/menu_items/#{item.id}",
            params: {
              menu_item: {
                name: 'Updated Pizza',
                tag_ids: [new_tag.id]
              }
            },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Pizza')
      expect(json_response['tags'].size).to eq(1)
      expect(json_response['tags'].first['name']).to eq('New Tag')
    end
  end

  describe 'DELETE /admin/v1/menu_items/:id' do
    let(:item) { create(:menu_item) }

    it 'deletes the menu item' do
      delete "/admin/v1/menu_items/#{item.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(MenuItem.exists?(item.id)).to be false
    end
  end
end
