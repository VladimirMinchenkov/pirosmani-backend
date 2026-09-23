require "rails_helper"

RSpec.describe "Admin::V1::DeliveryZones", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:headers) { auth_headers(admin_user) }

  describe "GET /admin/v1/delivery_zones" do
    it "returns all delivery zones ordered by created_at desc" do
      older = create(:delivery_zone, name: "Старая зона", created_at: 1.day.ago)
      newer = create(:delivery_zone, name: "Новая зона", created_at: 1.hour.ago)

      get "/admin/v1/delivery_zones", headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body.size).to eq(2)
      expect(body.first["name"]).to eq("Новая зона")
      expect(body.first).to have_key("coordinates")
      expect(body.first).to have_key("price")
      expect(body.first).to have_key("active")
    end

    it "returns 401 without auth" do
      get "/admin/v1/delivery_zones"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with invalid token" do
      get "/admin/v1/delivery_zones", headers: { "Authorization" => "Bearer invalid_token" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /admin/v1/delivery_zones/:id" do
    let(:zone) { create(:delivery_zone) }

    it "returns the delivery zone" do
      get "/admin/v1/delivery_zones/#{zone.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["name"]).to eq(zone.name)
      expect(json_response["price"]).to eq(zone.price.to_f)
      expect(json_response["active"]).to be true
    end

    it "returns 404 for non-existent zone" do
      get "/admin/v1/delivery_zones/0", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json_response["error"]).to eq("Delivery zone not found")
    end
  end

  describe "POST /admin/v1/delivery_zones" do
    let(:valid_params) do
      {
        delivery_zone: {
          name: "Новая зона доставки",
          active: true,
          price: 12.5,
          coordinates: [
            [38.05, 44.56],
            [38.07, 44.56],
            [38.07, 44.58],
            [38.05, 44.58],
            [38.05, 44.56]
          ]
        }
      }
    end

    it "creates a delivery zone" do
      post "/admin/v1/delivery_zones", params: valid_params, headers: headers

      expect(response).to have_http_status(:created)
      body = json_response
      expect(body["name"]).to eq("Новая зона доставки")
      expect(body["price"]).to eq(12.5)
      expect(body["active"]).to be true
      expect(body["coordinates"]).to be_an(Array)
    end

    it "returns 422 with invalid params" do
      post "/admin/v1/delivery_zones",
           params: { delivery_zone: { name: "" } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to be_present
    end

    it "returns 401 without auth" do
      post "/admin/v1/delivery_zones", params: valid_params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /admin/v1/delivery_zones/:id" do
    let(:zone) { create(:delivery_zone) }

    it "updates the delivery zone" do
      patch "/admin/v1/delivery_zones/#{zone.id}",
            params: { delivery_zone: { name: "Обновлённая зона", price: 20.0 } },
            headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body["name"]).to eq("Обновлённая зона")
      expect(body["price"]).to eq(20.0)
    end

    it "can deactivate a zone" do
      patch "/admin/v1/delivery_zones/#{zone.id}",
            params: { delivery_zone: { active: false } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["active"]).to be false
    end

    it "returns 422 with invalid params" do
      patch "/admin/v1/delivery_zones/#{zone.id}",
            params: { delivery_zone: { name: "" } },
            headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to be_present
    end

    it "returns 404 for non-existent zone" do
      patch "/admin/v1/delivery_zones/0",
            params: { delivery_zone: { name: "Ghost" } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/v1/delivery_zones/:id" do
    let!(:zone) { create(:delivery_zone) }

    it "deletes the delivery zone" do
      delete "/admin/v1/delivery_zones/#{zone.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(DeliveryZone.exists?(zone.id)).to be false
    end

    it "returns 404 for non-existent zone" do
      delete "/admin/v1/delivery_zones/0", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without auth" do
      delete "/admin/v1/delivery_zones/#{zone.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
