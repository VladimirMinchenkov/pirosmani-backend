require 'rails_helper'

RSpec.describe Addon, type: :model do
  describe 'associations' do
    it { should belong_to(:addon_group) }
    it { should have_many(:cart_item_addons).dependent(:nullify) }
    it { should have_many(:order_item_addons).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  end
end