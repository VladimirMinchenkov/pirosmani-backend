require 'rails_helper'

RSpec.describe "Webhooks::Telegram", type: :request do
  let(:client) { create(:client) }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "Хинкали", price: 25.0, category: category, available: true) }
  let!(:order) do
    order = Order.create!(client: client, order_type: "pickup", status: "pending", total_price: 25.0, delivery_price: 0.0)
    order.order_items.create!(menu_item: menu_item, quantity: 1, price: 25.0)
    order
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:telegram, :bot_token).and_return("test-bot-token")
  end

  describe "POST /webhooks/telegram" do
    it "переводит заказ в confirmed при нажатии Принять и отвечает на callback_query" do
      answer_stub = stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery})
        .to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: {
        callback_query: { id: "cb-1", data: "order:#{order.id}:confirm" }
      }

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("confirmed")
      expect(answer_stub).to have_been_requested
    end

    it "переводит заказ в cancelled при нажатии Отклонить" do
      stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery}).to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: {
        callback_query: { id: "cb-2", data: "order:#{order.id}:cancel" }
      }

      expect(order.reload.status).to eq("cancelled")
    end

    it "возвращает 200 даже для неизвестного формата callback_data" do
      stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery}).to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: { callback_query: { id: "cb-3", data: "garbage" } }

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("pending") # не изменился
    end

    it "возвращает 200, если заказ не найден" do
      stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery}).to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: { callback_query: { id: "cb-4", data: "order:999999:confirm" } }

      expect(response).to have_http_status(:ok)
    end

    it "возвращает 200 без callback_query в payload (обычное сообщение боту)" do
      post "/webhooks/telegram", params: { message: { text: "hello" } }
      expect(response).to have_http_status(:ok)
    end
  end
end
