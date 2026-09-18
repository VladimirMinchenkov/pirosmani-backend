require 'rails_helper'

RSpec.describe ProductGroup, type: :model do
  describe 'associations' do
    it { should have_many(:menu_items).dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:product_group) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_uniqueness_of(:slug) }
  end

  describe 'callbacks' do
    it 'generates slug from name' do
      group = create(:product_group, name: 'Hot Drinks', slug: nil)
      expect(group.slug).to eq('hot-drinks')
    end

    it 'keeps explicit slug if provided' do
      group = create(:product_group, name: 'Hot Drinks', slug: 'custom-slug')
      expect(group.slug).to eq('custom-slug')
    end
  end
end