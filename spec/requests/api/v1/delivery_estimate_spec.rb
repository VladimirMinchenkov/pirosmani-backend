require "rails_helper"

RSpec.describe "Api::V1::DeliveryEstimate", type: :request do
  describe "GET /api/v1/delivery_estimate" do
    let!(:zone) { create(:delivery_zone, price: 15.0) }

    context "with coordinates inside an active zone" do
      it "returns available: true with zone price" do
        get "/api/v1/delivery_estimate", params: { lat: 44.57, lng: 38.06 }

        expect(response).to have_http_status(:ok)
        body = json_response
        expect(body["available"]).to be true
        expect(body["price"]).to eq(15.0)
        expect(body["zone_id"]).to eq(zone.id)
        expect(body["zone_name"]).to eq(zone.name)
      end
    end

    context "with coordinates outside any active zone" do
      it "returns available: false with 406 status" do
        get "/api/v1/delivery_estimate", params: { lat: 44.60, lng: 38.06 }

        expect(response).to have_http_status(:not_acceptable)
        body = json_response
        expect(body["available"]).to be false
        expect(body["message"]).to be_present
      end
    end

    context "when only inactive zones cover the point" do
      before { zone.update!(active: false) }

      it "returns available: false" do
        get "/api/v1/delivery_estimate", params: { lat: 44.57, lng: 38.06 }

        expect(response).to have_http_status(:not_acceptable)
        expect(json_response["available"]).to be false
      end
    end

    context "without lat/lng parameters" do
      it "returns 400 bad request when both missing" do
        get "/api/v1/delivery_estimate"

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]).to eq("lat and lng are required")
      end

      it "returns 400 bad request when only lat provided" do
        get "/api/v1/delivery_estimate", params: { lat: 44.57 }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]).to eq("lat and lng are required")
      end

      it "returns 400 bad request when only lng provided" do
        get "/api/v1/delivery_estimate", params: { lng: 38.06 }

        expect(response).to have_http_status(:bad_request)
        expect(json_response["error"]).to eq("lat and lng are required")
      end
    end

    context "when multiple active zones exist" do
      let!(:far_zone) do
        create(:delivery_zone,
          name: "Дальняя зона",
          price: 25.0,
          coordinates: [
            [38.10, 44.60],
            [38.12, 44.60],
            [38.12, 44.62],
            [38.10, 44.62],
            [38.10, 44.60]
          ]
        )
      end

      it "returns the first matching active zone" do
        get "/api/v1/delivery_estimate", params: { lat: 44.57, lng: 38.06 }

        expect(response).to have_http_status(:ok)
        expect(json_response["available"]).to be true
        expect(json_response["zone_id"]).to eq(zone.id)
      end
    end
  end
end
