require 'rails_helper'

RSpec.describe "Api::V1::ClientAddresses", type: :request do
  let(:client) { create(:client, phone: "+79990000001") }
  let(:headers) { { "Authorization" => "Bearer #{Auth::JwtService.encode(client_id: client.id)}" } }
  let(:other_client) { create(:client, phone: "+79990000002") }

  describe "GET /api/v1/client_addresses" do
    it "returns only current client's addresses" do
      client.client_addresses.create!(street: "Ул. Своя")
      other_client.client_addresses.create!(street: "Ул. Чужая")

      get "/api/v1/client_addresses", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first["street"]).to eq("Ул. Своя")
    end
  end

  describe "POST /api/v1/client_addresses" do
    it "creates an address" do
      post "/api/v1/client_addresses", params: {
        client_address: { label: "Дом", street: "Ул. Новая", lat: 55.1, lng: 37.1 }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["label"]).to eq("Дом")
      expect(client.client_addresses.count).to eq(1)
    end

    it "rejects invalid address" do
      post "/api/v1/client_addresses", params: { client_address: { street: "" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/client_addresses/:id" do
    it "updates own address" do
      address = client.client_addresses.create!(street: "Старая")

      patch "/api/v1/client_addresses/#{address.id}", params: {
        client_address: { street: "Новая" }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(address.reload.street).to eq("Новая")
    end

    it "cannot update another client's address" do
      address = other_client.client_addresses.create!(street: "Чужая")

      patch "/api/v1/client_addresses/#{address.id}", params: {
        client_address: { street: "Хак" }
      }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/client_addresses/:id" do
    it "deletes own address" do
      address = client.client_addresses.create!(street: "Удаляемая")

      delete "/api/v1/client_addresses/#{address.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(ClientAddress.exists?(address.id)).to be false
    end
  end

  describe "unauthorized" do
    it "rejects without client" do
      get "/api/v1/client_addresses"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
