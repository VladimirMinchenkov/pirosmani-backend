require 'rails_helper'

RSpec.describe YandexDeliveryTrackingService do
  let(:client) { create(:client) }
  let(:address) { client.client_addresses.create!(street: "Ул. Тест", lat: 55.05, lng: 37.05) }
  let(:order) do
    Order.create!(
      client: client, order_type: "delivery", client_address: address,
      status: "pending", total_price: 50.0, delivery_price: 10.0,
      yandex_claim_id: "claim-123", yandex_claim_status: "delivering",
      claim_requested_at: 5.minutes.ago
    )
  end

  before do
    AppSetting.create!(key: "yandex_courier_mode", value: "real")
    Rails.cache.clear
  end

  describe "#snapshot" do
    it "собирает статус/позицию/ETA из реальных Yandex-эндпоинтов" do
      stub_request(:post, %r{/v2/claims/performer-position})
        .to_return(status: 200, body: { position: { lat: 55.06, lon: 37.06 } }.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:post, %r{/v2/claims/points-eta})
        .to_return(
          status: 200,
          body: { route_points: [{ type: "source", eta_sec: 0 }, { type: "destination", eta_sec: 600 }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      snapshot = described_class.snapshot(order)

      expect(snapshot[:status_key]).to eq("delivering")
      expect(snapshot[:status_label]).to eq("Курьер в пути")
      expect(snapshot[:lat]).to eq(55.06)
      expect(snapshot[:lng]).to eq(37.06)
      expect(snapshot[:eta_minutes]).to eq(10)
    end

    it "кэширует позицию на короткий TTL — второй вызов не бьёт Yandex повторно" do
      # test.rb использует :null_store (кэш всегда "промахивается") — для этого
      # теста явно подставляем реальный MemoryStore, чтобы проверить TTL-кэш
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      position_stub = stub_request(:post, %r{/v2/claims/performer-position})
        .to_return(status: 200, body: { position: { lat: 55.06, lon: 37.06 } }.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:post, %r{/v2/claims/points-eta})
        .to_return(status: 200, body: { route_points: [] }.to_json, headers: { "Content-Type" => "application/json" })

      described_class.snapshot(order)
      described_class.snapshot(order)

      expect(position_stub).to have_been_requested.times(1)
    end

    it "возвращает nil-позицию и не поднимает исключение, если Yandex ответил ошибкой" do
      stub_request(:post, %r{/v2/claims/performer-position}).to_return(status: 500, body: "boom")
      stub_request(:post, %r{/v2/claims/points-eta}).to_return(status: 500, body: "boom")

      snapshot = described_class.snapshot(order)

      expect(snapshot[:lat]).to be_nil
      expect(snapshot[:eta_minutes]).to be_nil
    end

    it "возвращает nil целиком, если заявка ещё не создана" do
      order.update!(claim_requested_at: nil)
      expect(described_class.snapshot(order)).to be_nil
    end
  end

  describe "#call_courier" do
    it "возвращает подменный номер от driver-voice-forwarding" do
      stub_request(:post, %r{/v2/driver-voice-forwarding})
        .to_return(status: 200, body: { phone: "+375291112233" }.to_json, headers: { "Content-Type" => "application/json" })

      result = described_class.call_courier(order)
      expect(result[:forwarding_number]).to eq("+375291112233")
    end

    it "поднимает Error, если Yandex не вернул номер" do
      stub_request(:post, %r{/v2/driver-voice-forwarding})
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect { described_class.call_courier(order) }.to raise_error(YandexDeliveryClaimService::Error)
    end
  end
end
