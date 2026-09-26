require 'rails_helper'

RSpec.describe TelegramOrderNotifierService do
  let(:client) { create(:client) }
  let!(:category) { Category.create!(name: "TestCat", position: 0) }
  let!(:menu_item) { MenuItem.create!(name: "Хинкали", price: 25.0, category: category, available: true) }
  let(:order) do
    order = Order.create!(client: client, order_type: "pickup", status: "pending", total_price: 25.0, delivery_price: 0.0)
    order.order_items.create!(menu_item: menu_item, quantity: 1, price: 25.0)
    order
  end

  before do
    AppSetting.create!(key: "telegram_orders_chat_id", value: "-100123456")
    allow(Rails.application.credentials).to receive(:dig).with(:telegram, :bot_token).and_return("test-bot-token")
  end

  describe "#notify_new_order!" do
    it "отправляет sendMessage с составом заказа и кнопками, сохраняет chat_id/message_id" do
      stub = stub_request(:post, %r{api\.telegram\.org/bot.*/sendMessage})
        .to_return(
          status: 200,
          body: { ok: true, result: { message_id: 555 } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      described_class.notify_new_order!(order)

      expect(stub).to have_been_requested
      expect(order.reload.telegram_chat_id).to eq("-100123456")
      expect(order.telegram_message_id).to eq(555)
    end

    it "ничего не делает и не падает, если chat_id не настроен" do
      AppSetting.find_by(key: "telegram_orders_chat_id").destroy!

      expect { described_class.notify_new_order!(order) }.not_to raise_error
      expect(order.reload.telegram_message_id).to be_nil
    end

    it "не падает, если Telegram API вернул ошибку" do
      stub_request(:post, %r{api\.telegram\.org/bot.*/sendMessage}).to_return(status: 400, body: { ok: false, description: "bad request" }.to_json)

      expect { described_class.notify_new_order!(order) }.not_to raise_error
      expect(order.reload.telegram_message_id).to be_nil
    end
  end

  describe "#update_status!" do
    before { order.update!(telegram_chat_id: "-100123456", telegram_message_id: 555) }

    it "делает editMessageText с новым статусом и кнопками (заказ ещё не финализирован)" do
      stub = stub_request(:post, %r{api\.telegram\.org/bot.*/editMessageText})
        .with { |req| body = JSON.parse(req.body); body["reply_markup"].present? }
        .to_return(status: 200, body: { ok: true }.to_json)

      # "cooking" — заказ уже принят, но ещё не финализирован (не confirmed/
      # cancelled/done), поэтому кнопки Принять/Отклонить по-прежнему видны
      order.update!(status: "cooking")
      described_class.update_status!(order)

      expect(stub).to have_been_requested
    end

    it "убирает кнопки, если заказ отменён" do
      stub = stub_request(:post, %r{api\.telegram\.org/bot.*/editMessageText})
        .with { |req| body = JSON.parse(req.body); body["reply_markup"].nil? }
        .to_return(status: 200, body: { ok: true }.to_json)

      order.update!(status: "cancelled")
      described_class.update_status!(order)

      expect(stub).to have_been_requested
    end

    it "ничего не делает, если у заказа нет telegram_message_id" do
      order.update!(telegram_message_id: nil)

      described_class.update_status!(order)

      expect(WebMock).not_to have_requested(:post, %r{api\.telegram\.org/bot.*/editMessageText})
    end
  end

  describe "#answer_callback!" do
    it "делает answerCallbackQuery" do
      stub = stub_request(:post, %r{api\.telegram\.org/bot.*/answerCallbackQuery})
        .to_return(status: 200, body: { ok: true }.to_json)

      described_class.answer_callback!("cb-1", "Заказ принят")

      expect(stub).to have_been_requested
    end
  end
end
