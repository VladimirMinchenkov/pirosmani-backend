require 'rails_helper'

RSpec.describe YandexDeliveryClaimService do
  let(:client) { create(:client) }
  let(:address) { client.client_addresses.create!(street: "Ул. Тест", lat: 55.05, lng: 37.05) }
  let(:order) do
    Order.create!(
      client: client, order_type: "delivery", client_address: address,
      status: "pending", total_price: 50.0, delivery_price: 10.0
    )
  end

  describe "mock mode (yandex_courier_mode not set / mock)" do
    it "create_and_accept! создаёт mock-заявку без единого сетевого запроса" do
      described_class.create_and_accept!(order)
      order.reload

      expect(order.yandex_claim_id).to start_with("mock-")
      expect(order.yandex_claim_status).to eq("new")
      expect(order.courier_name).to be_present
      expect(order.claim_requested_at).to be_present
    end

    it "идемпотентно — повторный вызов ничего не делает" do
      described_class.create_and_accept!(order)
      first_claim_id = order.reload.yandex_claim_id

      described_class.create_and_accept!(order)
      expect(order.reload.yandex_claim_id).to eq(first_claim_id)
    end

    it "cancel! помечает mock-заявку отменённой" do
      described_class.create_and_accept!(order)
      described_class.cancel!(order)
      expect(order.reload.yandex_claim_status).to eq("cancelled")
    end
  end

  describe "real mode" do
    before { AppSetting.create!(key: "yandex_courier_mode", value: "real") }

    describe "#create_and_accept!" do
      it "делает claims/create затем claims/accept и сохраняет claim_id/status" do
        create_stub = stub_request(:post, %r{/v2/claims/create})
          .to_return(
            status: 200,
            body: { id: "claim-123", version: 1, status: "new" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        accept_stub = stub_request(:post, %r{/v2/claims/accept/claim-123})
          .to_return(
            status: 200,
            body: { id: "claim-123", version: 2, status: "accepted" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        described_class.create_and_accept!(order)
        order.reload

        expect(create_stub).to have_been_requested
        expect(accept_stub).to have_been_requested
        expect(order.yandex_claim_id).to eq("claim-123")
        expect(order.yandex_claim_status).to eq("accepted")
        expect(order.claim_requested_at).to be_present
      end

      it "сохраняет реальную цену заявки (pricing.offer.price) для сравнения с order.delivery_price" do
        stub_request(:post, %r{/v2/claims/create})
          .to_return(
            status: 200,
            body: { id: "claim-123", version: 1, status: "new", pricing: { offer: { price: "10.00" } } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        stub_request(:post, %r{/v2/claims/accept/claim-123})
          .to_return(status: 200, body: { status: "accepted" }.to_json, headers: { "Content-Type" => "application/json" })

        described_class.create_and_accept!(order)

        expect(order.reload.yandex_actual_claim_price).to eq(10.0)
      end

      it "не падает, если Yandex не вернул поле цены" do
        stub_request(:post, %r{/v2/claims/create})
          .to_return(status: 200, body: { id: "claim-123", version: 1, status: "new" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:post, %r{/v2/claims/accept/claim-123})
          .to_return(status: 200, body: { status: "accepted" }.to_json, headers: { "Content-Type" => "application/json" })

        described_class.create_and_accept!(order)

        expect(order.reload.yandex_actual_claim_price).to be_nil
      end

      it "сохраняет предварительное ETA (route_points destination.eta_sec) — доступно сразу, без вебхука" do
        stub_request(:post, %r{/v2/claims/create})
          .to_return(
            status: 200,
            body: {
              id: "claim-123", version: 1, status: "new",
              route_points: [
                { type: "source", eta_sec: 0 },
                { type: "destination", eta_sec: 900 }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        stub_request(:post, %r{/v2/claims/accept/claim-123})
          .to_return(status: 200, body: { status: "accepted" }.to_json, headers: { "Content-Type" => "application/json" })

        described_class.create_and_accept!(order)

        expect(order.reload.yandex_claim_eta_minutes).to eq(15) # 900 сек = 15 мин
      end

      it "поднимает Error с осмысленной причиной отказа, если тариф недоступен для маршрута" do
        stub_request(:post, %r{/v2/claims/create})
          .to_return(
            status: 400,
            body: { message: "no_such_tariff: route is not covered by any available tariff" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        expect { described_class.create_and_accept!(order) }
          .to raise_error(described_class::Error, /route is not covered by any available tariff/)
      end

      it "поднимает Error, если Yandex вернул ошибку" do
        stub_request(:post, %r{/v2/claims/create}).to_return(status: 500, body: "boom")

        expect { described_class.create_and_accept!(order) }.to raise_error(described_class::Error)
      end

      it "поднимает Error, если ответ не содержит id заявки" do
        stub_request(:post, %r{/v2/claims/create}).to_return(
          status: 200, body: { status: "new" }.to_json, headers: { "Content-Type" => "application/json" }
        )

        expect { described_class.create_and_accept!(order) }.to raise_error(described_class::Error)
      end

      it "идемпотентно — не делает запросов, если claim уже создан" do
        order.update!(yandex_claim_id: "already-there")

        described_class.create_and_accept!(order)

        expect(WebMock).not_to have_requested(:post, %r{/v2/claims/create})
      end
    end

    describe "#cancel!" do
      before { order.update!(yandex_claim_id: "claim-123", yandex_claim_status: "performer_found") }

      it "отменяет бесплатно (cancel_state=free) без allow_paid" do
        stub_request(:post, %r{/v2/claims/cancel-info/claim-123})
          .to_return(status: 200, body: { cancel_state: "free" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:post, %r{/v2/claims/info/claim-123})
          .to_return(status: 200, body: { version: 3 }.to_json, headers: { "Content-Type" => "application/json" })
        cancel_stub = stub_request(:post, %r{/v2/claims/cancel/claim-123})
          .to_return(status: 200, body: { status: "cancelled" }.to_json, headers: { "Content-Type" => "application/json" })

        described_class.cancel!(order)

        expect(cancel_stub).to have_been_requested
        expect(order.reload.yandex_claim_status).to eq("cancelled")
      end

      it "поднимает Error при платной отмене без allow_paid: true (не тратим деньги без подтверждения)" do
        stub_request(:post, %r{/v2/claims/cancel-info/claim-123})
          .to_return(status: 200, body: { cancel_state: "paid" }.to_json, headers: { "Content-Type" => "application/json" })

        expect { described_class.cancel!(order) }.to raise_error(described_class::Error, /paid/)
        expect(order.reload.yandex_claim_status).to eq("performer_found") # не изменился
      end

      it "отменяет платно, если allow_paid: true явно передан" do
        stub_request(:post, %r{/v2/claims/cancel-info/claim-123})
          .to_return(status: 200, body: { cancel_state: "paid" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:post, %r{/v2/claims/info/claim-123})
          .to_return(status: 200, body: { version: 3 }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:post, %r{/v2/claims/cancel/claim-123})
          .to_return(status: 200, body: { status: "cancelled" }.to_json, headers: { "Content-Type" => "application/json" })

        described_class.cancel!(order, allow_paid: true)

        expect(order.reload.yandex_claim_status).to eq("cancelled")
      end

      it "ничего не делает, если заявка не создана" do
        order.update!(yandex_claim_id: nil)

        described_class.cancel!(order)

        expect(WebMock).not_to have_requested(:post, %r{/v2/claims/cancel-info})
      end
    end
  end
end
