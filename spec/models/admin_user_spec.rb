require 'rails_helper'

RSpec.describe AdminUser, type: :model do
  describe 'validations' do
    subject { build(:admin_user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
  end

  describe 'callbacks' do
    it 'generates access_token before create' do
      admin_user = build(:admin_user, access_token: nil)
      admin_user.save!
      expect(admin_user.access_token).to be_present
    end
  end
end