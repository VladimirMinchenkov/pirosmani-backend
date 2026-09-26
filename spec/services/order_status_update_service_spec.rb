require 'rails_helper'

RSpec.describe OrderStatusUpdateService do
  include ActiveJob::TestHelper

  let(:client) { create(:client) }
  let!(:client_address) { client.client_addresses.create!(street: "Ул. Тест", lat: 52.10, lng: 23.70) }
  let(:order) { create(:order, client: client, client_address: client_address, order_type: "delivery", status: "pending") }

  before do
    # Уведомление в Telegram не должно ронять смену статуса, даже если оно
    # не настроено (нет chat_id/bot_token) — тихо no-op
  end

  it "обновляет статус заказа" do
    expect(described_class.update!(order, status: "confirmed")).to eq(true)
    expect(order.reload.status).to eq("confirmed")
  end

  it "планирует ClaimCreationJob при переходе в cooking (та же логика, что и в admin-контроллере)" do
    expect {
      described_class.update!(order, status: "cooking")
    }.to have_enqueued_job(ClaimCreationJob).with(order.id)

    order.reload
    expect(order.cooking_started_at).to be_present
    expect(order.claim_planned_at).to be_present
  end

  it "вызывает TelegramOrderNotifierService.update_status! после смены статуса" do
    expect(TelegramOrderNotifierService).to receive(:update_status!).with(order)

    described_class.update!(order, status: "confirmed")
  end

  it "возвращает false и не трогает джобы при недопустимом статусе" do
    expect { described_class.update!(order, status: "not_a_real_status") }.to raise_error(ArgumentError)
  end
end
