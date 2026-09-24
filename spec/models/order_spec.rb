require 'rails_helper'

RSpec.describe Order, type: :model do
  describe "bonus callback" do
    let(:client) { create(:client, bonus_points: 0) }
    # delivery_price: 0 — бонусы намеренно начисляются только с суммы блюд (см. Order#award_bonus_points),
    # поэтому фиксируем его явно, чтобы числовые ожидания ниже (floor(45.50)=45 и т.д.) были верны
    let(:order) { create(:order, client: client, total_price: 45.50, delivery_price: 0, bonus_points_used: 0, status: "pending") }

    describe "#award_bonus_points (after_update to done)" do
      it "awards bonus points when status changes to done" do
        expect { order.update!(status: "done") }
          .to change { client.reload.bonus_points }.by(45) # floor(45.50) = 45
      end

      it "creates an earn transaction" do
        expect { order.update!(status: "done") }
          .to change { client.bonus_transactions.earnings.count }.by(1)
      end

      it "deducts bonus_points_used from earned amount" do
        order.update!(bonus_points_used: 100, total_price: 50.00)
        # paid_by_money = 50.00 - (100 * 0.01) = 50.00 - 1.00 = 49.00
        # floor(49.00) = 49
        expect { order.update!(status: "done") }
          .to change { client.reload.bonus_points }.by(49)
      end

      it "does not award points when already earned (idempotent)" do
        order.update!(status: "done")
        client.reload
        initial_points = client.bonus_points

        # Change status back and forth
        order.update!(status: "cooking")
        order.update!(status: "done")

        expect(client.reload.bonus_points).to eq(initial_points)
      end

      it "does not award points for non-done status changes" do
        expect { order.update!(status: "confirmed") }
          .not_to change { client.reload.bonus_points }
      end

      it "does not award points when status changes from done to something else" do
        order.update!(status: "done")
        client.reload
        initial_points = client.bonus_points

        order.update!(status: "cancelled")
        expect(client.reload.bonus_points).to eq(initial_points)
      end

      it "awards 0 points when total_price is less than 1 BYN" do
        order.update!(total_price: 0.50)
        expect { order.update!(status: "done") }
          .not_to change { client.reload.bonus_points }
      end

      it "awards 0 points when total_price is fully covered by bonuses" do
        order.update!(total_price: 5.00, bonus_points_used: 500)
        # paid_by_money = 5.00 - 5.00 = 0
        expect { order.update!(status: "done") }
          .not_to change { client.reload.bonus_points }
      end
    end
  end
end
