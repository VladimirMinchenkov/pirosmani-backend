require 'rails_helper'

RSpec.describe Client, type: :model do
  describe "валидация phone" do
    it "требует phone для обычного клиента (телефон+OTP)" do
      client = Client.new(phone: nil, name: "Тест")
      expect(client).not_to be_valid
      expect(client.errors[:phone]).to be_present
    end

    it "не требует phone для Telegram-клиента (telegram_user_id присутствует)" do
      client = Client.new(telegram_user_id: 123, name: "Тест", phone: nil)
      expect(client).to be_valid
    end
  end

  describe "bonus methods" do
    let(:client) { create(:client, bonus_points: 200) }
    let(:order) { create(:order, client: client, total_price: 45.50) }

    describe "#earn_bonuses!" do
      it "adds bonus points to client" do
        expect { client.earn_bonuses!(45, order: order) }
          .to change { client.reload.bonus_points }.by(45)
      end

      it "creates an earn transaction" do
        expect { client.earn_bonuses!(45, order: order) }
          .to change { client.bonus_transactions.earnings.count }.by(1)
      end

      it "sets correct transaction attributes" do
        client.earn_bonuses!(45, order: order)
        tx = client.bonus_transactions.last
        expect(tx.kind).to eq("earn")
        expect(tx.amount).to eq(45)
        expect(tx.order).to eq(order)
        expect(tx.description).to include("##{order.id}")
      end

      it "uses custom description when provided" do
        client.earn_bonuses!(10, order: order, description: "Welcome bonus")
        expect(client.bonus_transactions.last.description).to eq("Welcome bonus")
      end

      it "does nothing when amount is zero" do
        expect { client.earn_bonuses!(0, order: order) }
          .not_to change { client.reload.bonus_points }
        expect { client.earn_bonuses!(0, order: order) }
          .not_to change { client.bonus_transactions.count }
      end

      it "does nothing when amount is negative" do
        expect { client.earn_bonuses!(-5, order: order) }
          .not_to change { client.reload.bonus_points }
      end

      it "rolls back both transaction and points on error" do
        allow(client.bonus_transactions).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(BonusTransaction.new))
        begin
          client.earn_bonuses!(45, order: order)
        rescue ActiveRecord::RecordInvalid
          # expected
        end
        expect(client.reload.bonus_points).to eq(200)
      end
    end

    describe "#spend_bonuses!" do
      it "deducts bonus points from client" do
        expect { client.spend_bonuses!(50, order: order) }
          .to change { client.reload.bonus_points }.by(-50)
      end

      it "creates a spend transaction" do
        expect { client.spend_bonuses!(50, order: order) }
          .to change { client.bonus_transactions.spendings.count }.by(1)
      end

      it "caps spending at available balance" do
        spent = client.spend_bonuses!(300, order: order)
        expect(spent).to eq(200)
        expect(client.reload.bonus_points).to eq(0)
      end

      it "returns 0 when balance is 0" do
        client.update!(bonus_points: 0)
        spent = client.spend_bonuses!(50, order: order)
        expect(spent).to eq(0)
      end

      it "returns 0 when amount is 0" do
        spent = client.spend_bonuses!(0, order: order)
        expect(spent).to eq(0)
      end

      it "rolls back on error" do
        allow(client.bonus_transactions).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(BonusTransaction.new))
        begin
          client.spend_bonuses!(50, order: order)
        rescue ActiveRecord::RecordInvalid
          # expected
        end
        expect(client.reload.bonus_points).to eq(200)
      end
    end

    describe "#max_spendable_bonuses" do
      it "returns min of balance and 10% of order total in bonus points" do
        # 10% of 45.50 BYN = 4.55 BYN = 455 bonus points
        # balance is 200, so max is 200
        expect(client.max_spendable_bonuses(45.50)).to eq(200)
      end

      it "caps at 10% of order total when balance is high" do
        client.update!(bonus_points: 5000)
        # 10% of 100 BYN = 10 BYN = 1000 bonus points
        expect(client.max_spendable_bonuses(100)).to eq(1000)
      end

      it "returns 0 when balance is 0" do
        client.update!(bonus_points: 0)
        expect(client.max_spendable_bonuses(100)).to eq(0)
      end

      it "returns 0 when order total is 0" do
        expect(client.max_spendable_bonuses(0)).to eq(0)
      end
    end
  end
end
