require 'rails_helper'

RSpec.describe "Webhooks::Telegram", type: :request do
  let(:client) { create(:client) }
  let(:secret_token) { "test-webhook-secret-123" }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "Хинкали", price: 25.0, category: category, available: true) }
  let!(:order) do
    order = Order.create!(client: client, order_type: "pickup", status: "pending", total_price: 25.0, delivery_price: 0.0)
    order.order_items.create!(menu_item: menu_item, quantity: 1, price: 25.0)
    order
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:telegram, :pirosmani_brest_delivery_bot_token).and_return("test-bot-token")
    allow(Rails.application.credentials).to receive(:dig).with(:telegram, :webhook_secret_token).and_return(secret_token)
  end

  let(:valid_headers) { { "X-Telegram-Bot-Api-Secret-Token" => secret_token } }

  describe "POST /webhooks/telegram — защита secret_token" do
    it "возвращает 403, если заголовок X-Telegram-Bot-Api-Secret-Token отсутствует (защита от подделки callback_data)" do
      post "/webhooks/telegram", params: {
        callback_query: { id: "cb-fake", data: "order:#{order.id}:confirm" }
      }

      expect(response).to have_http_status(:forbidden)
      expect(order.reload.status).to eq("pending") # заказ НЕ изменился
    end

    it "возвращает 403, если заголовок неверный" do
      post "/webhooks/telegram",
        params: { callback_query: { id: "cb-fake", data: "order:#{order.id}:confirm" } },
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "wrong-secret" }

      expect(response).to have_http_status(:forbidden)
      expect(order.reload.status).to eq("pending")
    end

    it "пропускает запрос, если secret_token не настроен в credentials (обратная совместимость для окружений без него)" do
      allow(Rails.application.credentials).to receive(:dig).with(:telegram, :webhook_secret_token).and_return(nil)
      stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery}).to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: { callback_query: { id: "cb-1", data: "order:#{order.id}:confirm" } }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /webhooks/telegram" do
    it "переводит заказ в confirmed при нажатии Принять и отвечает на callback_query" do
      answer_stub = stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery})
        .to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: {
        callback_query: { id: "cb-1", data: "order:#{order.id}:confirm" }
      }, headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("confirmed")
      expect(answer_stub).to have_been_requested
    end

    it "переводит заказ в cancelled при нажатии Отклонить" do
      stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery}).to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: {
        callback_query: { id: "cb-2", data: "order:#{order.id}:cancel" }
      }, headers: valid_headers

      expect(order.reload.status).to eq("cancelled")
    end

    it "возвращает 200 даже для неизвестного формата callback_data" do
      stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery}).to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: { callback_query: { id: "cb-3", data: "garbage" } }, headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("pending") # не изменился
    end

    it "возвращает 200, если заказ не найден" do
      stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery}).to_return(status: 200, body: { ok: true }.to_json)

      post "/webhooks/telegram", params: { callback_query: { id: "cb-4", data: "order:999999:confirm" } }, headers: valid_headers

      expect(response).to have_http_status(:ok)
    end

    it "возвращает 200 без callback_query в payload (обычное сообщение боту)" do
      post "/webhooks/telegram", params: { message: { text: "hello" } }, headers: valid_headers
      expect(response).to have_http_status(:ok)
    end
  end
end
