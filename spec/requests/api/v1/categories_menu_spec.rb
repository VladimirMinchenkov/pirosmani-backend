require 'rails_helper'

RSpec.describe "Api::V1::Categories#menu", type: :request do
  let(:category) { create(:category, name: 'Хинкали', position: 1) }

  def json
    JSON.parse(response.body)
  end

  describe 'GET /api/v1/categories/:id/menu' do
    it 'returns category with mixed items' do
      # Самостоятельное блюдо
      create(:menu_item, name: 'Хинкали Мама', category: category,
             menu_item_group: nil, position_in_category: 2, available: true)

      # Группа с блюдами
      group = create(:menu_item_group, name: 'Хинкали', category: category,
                     position_in_category: 1, available: true)
      create(:menu_item, name: 'С бараниной', category: category,
             menu_item_group: group, position_in_group: 1, available: true)
      create(:menu_item, name: 'С сыром', category: category,
             menu_item_group: group, position_in_group: 2, available: true)

      get "/api/v1/categories/#{category.id}/menu"

      expect(response).to have_http_status(:ok)
      expect(json['category']['name']).to eq('Хинкали')
      expect(json['items'].size).to eq(2)

      # Первый элемент — группа (position_in_category: 1)
      expect(json['items'][0]['type']).to eq('menu_item_group')
      expect(json['items'][0]['name']).to eq('Хинкали')
      expect(json['items'][0]['items'].size).to eq(2)
      expect(json['items'][0]['items'][0]['name']).to eq('С бараниной')
      expect(json['items'][0]['items'][1]['name']).to eq('С сыром')

      # Второй элемент — самостоятельное блюдо (position_in_category: 2)
      expect(json['items'][1]['type']).to eq('menu_item')
      expect(json['items'][1]['name']).to eq('Хинкали Мама')
    end

    it 'returns 404 for non-existent category' do
      get '/api/v1/categories/0/menu'
      expect(response).to have_http_status(:not_found)
    end

    it 'filters out unavailable items' do
      create(:menu_item, name: 'Hidden', category: category,
             menu_item_group: nil, position_in_category: 1, available: false)

      get "/api/v1/categories/#{category.id}/menu"
      expect(json['items']).to be_empty
    end
  end
end