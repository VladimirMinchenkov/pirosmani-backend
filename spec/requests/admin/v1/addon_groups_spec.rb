require 'rails_helper'

RSpec.describe "Admin::V1::AddonGroups", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe 'GET /admin/v1/addon_groups' do
    it 'returns all addon groups with addons' do
      group = create(:addon_group, :with_addons, addons_count: 2)

      get '/admin/v1/addon_groups', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(1)
      expect(json_response.first['addons'].size).to eq(2)
    end
  end

  describe 'GET /admin/v1/addon_groups/:id' do
    let(:group) { create(:addon_group, :with_addons) }

    it 'returns the addon group with addons' do
      get "/admin/v1/addon_groups/#{group.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq(group.name)
      expect(json_response['addons']).not_to be_empty
    end
  end

  describe 'POST /admin/v1/addon_groups' do
    it 'creates an addon group' do
      post '/admin/v1/addon_groups',
           params: { addon_group: { name: 'Toppings', min_selection: 0, max_selection: 5, required: false } },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Toppings')
    end
  end

  describe 'PATCH /admin/v1/addon_groups/:id' do
    let(:group) { create(:addon_group) }

    it 'updates the addon group' do
      patch "/admin/v1/addon_groups/#{group.id}",
            params: { addon_group: { name: 'Updated Toppings' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Toppings')
    end
  end

  describe 'DELETE /admin/v1/addon_groups/:id' do
    let(:group) { create(:addon_group) }

    it 'deletes the addon group' do
      delete "/admin/v1/addon_groups/#{group.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(AddonGroup.exists?(group.id)).to be false
    end
  end

  describe 'nested addons' do
    let(:group) { create(:addon_group) }

    describe 'POST /admin/v1/addon_groups/:addon_group_id/addons' do
      it 'creates an addon within the group' do
        post "/admin/v1/addon_groups/#{group.id}/addons",
             params: { addon: { name: 'Extra Cheese', price: 2.50, position: 1 } },
             headers: headers

        expect(response).to have_http_status(:created)
        expect(json_response['name']).to eq('Extra Cheese')
        expect(json_response['price']).to eq(2.5)
      end
    end

    describe 'PATCH /admin/v1/addon_groups/:addon_group_id/addons/:id' do
      let(:addon) { create(:addon, addon_group: group) }

      it 'updates the addon' do
        patch "/admin/v1/addon_groups/#{group.id}/addons/#{addon.id}",
              params: { addon: { name: 'Double Cheese', price: 3.00 } },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Double Cheese')
      end
    end

    describe 'DELETE /admin/v1/addon_groups/:addon_group_id/addons/:id' do
      let(:addon) { create(:addon, addon_group: group) }

      it 'deletes the addon' do
        delete "/admin/v1/addon_groups/#{group.id}/addons/#{addon.id}", headers: headers

        expect(response).to have_http_status(:no_content)
        expect(Addon.exists?(addon.id)).to be false
      end
    end
  end
end