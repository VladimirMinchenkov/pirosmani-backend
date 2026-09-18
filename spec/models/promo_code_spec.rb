require 'rails_helper'

RSpec.describe PromoCode, type: :model do
  describe 'associations' do
    it { should have_many(:orders) }
  end

  describe 'validations' do
    subject { build(:promo_code) }

    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_inclusion_of(:discount_type).in_array(PromoCode::DISCOUNT_TYPES) }
    it { should validate_numericality_of(:discount_value).is_greater_than(0) }
    it { should validate_numericality_of(:usage_limit).only_integer.is_greater_than(0) }
  end

  describe 'scopes' do
    it '.active_now returns active and valid promos' do
      active = create(:promo_code, active: true)
      inactive = create(:promo_code, :inactive)
      expired = create(:promo_code, :expired)

      expect(PromoCode.active_now).to include(active)
      expect(PromoCode.active_now).not_to include(inactive)
      expect(PromoCode.active_now).not_to include(expired)
    end
  end

  describe '#usable?' do
    it 'returns true for valid promo code' do
      promo = build(:promo_code, active: true)
      expect(promo).to be_usable
    end

    it 'returns false for inactive promo' do
      promo = build(:promo_code, :inactive)
      expect(promo).not_to be_usable
    end

    it 'returns false for expired promo' do
      promo = build(:promo_code, :expired)
      expect(promo).not_to be_usable
    end

    it 'returns false for depleted promo' do
      promo = build(:promo_code, :depleted)
      expect(promo).not_to be_usable
    end
  end

  describe '#apply_to' do
    it 'applies fixed discount' do
      promo = build(:promo_code, discount_type: 'fixed', discount_value: 10)
      expect(promo.apply_to(50)).to eq(40)
    end

    it 'applies percent discount' do
      promo = build(:promo_code, discount_type: 'percent', discount_value: 20)
      expect(promo.apply_to(100)).to eq(80)
    end

    it 'does not go below zero' do
      promo = build(:promo_code, discount_type: 'fixed', discount_value: 100)
      expect(promo.apply_to(50)).to eq(0)
    end
  end
end