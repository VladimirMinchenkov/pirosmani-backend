require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'associations' do
    it { should have_many(:menu_item_tags).dependent(:destroy) }
    it { should have_many(:menu_items).through(:menu_item_tags) }
  end

  describe 'validations' do
    subject { build(:tag) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_uniqueness_of(:slug) }
  end

  describe 'callbacks' do
    it 'generates slug from name' do
      tag = create(:tag, name: 'Spicy Food', slug: nil)
      expect(tag.slug).to eq('spicy-food')
    end

    it 'keeps explicit slug if provided' do
      tag = create(:tag, name: 'Spicy Food', slug: 'custom-slug')
      expect(tag.slug).to eq('custom-slug')
    end
  end
end