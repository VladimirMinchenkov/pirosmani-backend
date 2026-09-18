require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it { should have_many(:menu_items).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }

    it 'validates uniqueness of name' do
      create(:category, name: 'Unique')
      expect(build(:category, name: 'Unique')).not_to be_valid
    end
    it { should validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  end
end