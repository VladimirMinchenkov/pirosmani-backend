require 'rails_helper'

RSpec.describe BonusTransaction, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      client = create(:client)
      order = create(:order, client: client)
      bt = build(:bonus_transaction, client: client, order: order)
      expect(bt).to be_valid
    end

    it "requires kind to be earn or spend" do
      client = create(:client)
      order = create(:order, client: client)
      bt = build(:bonus_transaction, client: client, order: order, kind: "invalid")
      expect(bt).not_to be_valid
      expect(bt.errors[:kind]).to be_present
    end

    it "requires amount to be positive" do
      client = create(:client)
      order = create(:order, client: client)
      bt = build(:bonus_transaction, client: client, order: order, amount: 0)
      expect(bt).not_to be_valid
      expect(bt.errors[:amount]).to be_present
    end

    it "requires amount to be integer" do
      client = create(:client)
      order = create(:order, client: client)
      bt = build(:bonus_transaction, client: client, order: order, amount: 1.5)
      expect(bt).not_to be_valid
    end

    it "requires description" do
      client = create(:client)
      order = create(:order, client: client)
      bt = build(:bonus_transaction, client: client, order: order, description: nil)
      expect(bt).not_to be_valid
    end

    it "allows order to be nil" do
      client = create(:client)
      bt = build(:bonus_transaction, client: client, order: nil, description: "Manual adjustment")
      expect(bt).to be_valid
    end
  end

  describe "scopes" do
    let(:client) { create(:client) }
    let(:order) { create(:order, client: client) }

    before do
      create(:bonus_transaction, :earn, client: client, order: order, amount: 100, created_at: 3.days.ago)
      create(:bonus_transaction, :spend, client: client, order: order, amount: 30, created_at: 2.days.ago)
      create(:bonus_transaction, :earn, client: client, order: order, amount: 50, created_at: 1.day.ago)
    end

    it "filters earnings" do
      expect(client.bonus_transactions.earnings.count).to eq(2)
      expect(client.bonus_transactions.earnings.sum(:amount)).to eq(150)
    end

    it "filters spendings" do
      expect(client.bonus_transactions.spendings.count).to eq(1)
      expect(client.bonus_transactions.spendings.sum(:amount)).to eq(30)
    end

    it "orders by recent first" do
      amounts = client.bonus_transactions.recent.pluck(:amount)
      expect(amounts).to eq([50, 30, 100])
    end
  end
end