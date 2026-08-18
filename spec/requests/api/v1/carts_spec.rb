require 'rails_helper'

RSpec.describe "Api::V1::Carts", type: :request do
  describe "GET /show" do
    it "returns http success" do
      get "/api/v1/carts/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/api/v1/carts/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/api/v1/carts/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
