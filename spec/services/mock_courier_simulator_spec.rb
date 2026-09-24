require 'rails_helper'

RSpec.describe MockCourierSimulator do
  describe ".status_for" do
    it "returns 'new' right after creation" do
      expect(described_class.status_for(0.0)[:key]).to eq("new")
    end

    it "progresses through performer_lookup" do
      expect(described_class.status_for(2.0)[:key]).to eq("performer_lookup")
    end

    it "progresses to performer_found around move_start" do
      expect(described_class.status_for(4.5)[:key]).to eq("performer_found")
    end

    it "progresses to pickup_arrived" do
      expect(described_class.status_for(5.5)[:key]).to eq("pickup_arrived")
    end

    it "progresses to delivering" do
      expect(described_class.status_for(15.0)[:key]).to eq("delivering")
    end

    it "reaches delivered after ETA" do
      expect(described_class.status_for(31.0)[:key]).to eq("delivered")
    end
  end

  describe ".position_for" do
    let(:from) { [52.0, 23.0] }
    let(:to) { [52.1, 23.1] }

    it "stays at cafe before move_start" do
      pos = described_class.position_for(2.0, from: from, to: to, eta_minutes: 30.0)
      expect(pos).to eq(from)
    end

    it "is halfway around the middle of the trip" do
      # move_start=5, eta=30 => середина движения ~17.5
      pos = described_class.position_for(17.5, from: from, to: to, eta_minutes: 30.0)
      expect(pos[0]).to be_within(0.01).of((from[0] + to[0]) / 2)
      expect(pos[1]).to be_within(0.01).of((from[1] + to[1]) / 2)
    end

    it "reaches destination at/after eta" do
      pos = described_class.position_for(35.0, from: from, to: to, eta_minutes: 30.0)
      expect(pos).to eq(to)
    end
  end

  describe ".eta_remaining_minutes" do
    it "counts down" do
      expect(described_class.eta_remaining_minutes(10.0, eta_minutes: 30.0)).to eq(20)
    end

    it "never goes below zero" do
      expect(described_class.eta_remaining_minutes(50.0, eta_minutes: 30.0)).to eq(0)
    end
  end

  describe ".generate_courier_snapshot" do
    it "is deterministic for the same seed" do
      a = described_class.generate_courier_snapshot(42)
      b = described_class.generate_courier_snapshot(42)
      expect(a).to eq(b)
    end

    it "returns name, vehicle and phone_masked" do
      snapshot = described_class.generate_courier_snapshot(1)
      expect(snapshot).to include(:name, :vehicle, :phone_masked)
    end
  end
end
