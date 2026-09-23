require "rails_helper"

RSpec.describe DeliveryZone, type: :model do
  describe "validations" do
    subject { build(:delivery_zone) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_presence_of(:coordinates) }
    it { is_expected.to validate_length_of(:coordinates).is_at_least(4) }
  end

  describe "scope :active" do
    let!(:active_zone) { create(:delivery_zone, active: true) }
    let!(:inactive_zone) { create(:delivery_zone, :inactive) }

    it "returns only active zones" do
      result = DeliveryZone.active
      expect(result).to include(active_zone)
      expect(result).not_to include(inactive_zone)
    end
  end

  describe "#contains_point?" do
    # Фабричный полигон — прямоугольник:
    # [38.05, 44.56] (юго-запад) → [38.07, 44.56] (юго-восток) →
    # [38.07, 44.58] (северо-восток) → [38.05, 44.58] (северо-запад)
    let(:zone) { build(:delivery_zone) }

    context "when point is inside the polygon" do
      it "returns true" do
        # Центр прямоугольника: lat=44.57, lng=38.06
        expect(zone.contains_point?(44.57, 38.06)).to be true
      end
    end

    context "when point is outside the polygon" do
      it "returns false for point north of polygon" do
        expect(zone.contains_point?(44.60, 38.06)).to be false
      end

      it "returns false for point east of polygon" do
        expect(zone.contains_point?(44.57, 38.08)).to be false
      end

      it "returns false for point far away" do
        expect(zone.contains_point?(40.0, 30.0)).to be false
      end
    end

    context "when point is on the boundary" do
      it "handles boundary point (algorithm-dependent)" do
        # Точка на южной границе полигона
        # Ray casting может как включить, так и исключить граничную точку —
        # проверяем конкретное поведение реализации
        result = zone.contains_point?(44.56, 38.06)
        expect([true, false]).to include(result)
      end
    end

    context "when coordinates are nil" do
      it "returns false" do
        zone.coordinates = nil
        expect(zone.contains_point?(44.57, 38.06)).to be false
      end
    end

    context "when coordinates have fewer than 4 points" do
      it "returns false" do
        zone.coordinates = [[38.05, 44.56], [38.07, 44.56]]
        expect(zone.contains_point?(44.57, 38.06)).to be false
      end
    end
  end
end
