# spec/models/cart_spec.rb
require 'rails_helper'

RSpec.describe Cart, type: :model do
  it { should belong_to(:client).optional }
  it { should have_many(:cart_items).dependent(:destroy) }
  it { should have_many(:products).through(:cart_items) }

  describe 'validations' do
    it 'валидна с client_id и без session_id' do
      cart = build(:cart, client: create(:client), session_id: nil)
      expect(cart).to be_valid
    end

    it 'валидна с session_id и без client_id' do
      cart = build(:cart, client: nil, session_id: SecureRandom.uuid)
      expect(cart).to be_valid
    end

    it 'невалидна, если оба поля пусты' do
      cart = build(:cart, client: nil, session_id: nil)
      expect(cart).not_to be_valid
      expect(cart.errors[:base]).to include("Должен быть указан либо client_id, либо session_id")
    end

    it "невалидна на уровне БД (check constraint), если оба поля заполнены" do
      cart = build(:cart, client: create(:client), session_id: SecureRandom.uuid)

      expect {
        cart.save(validate: false)
      }.to raise_error(ActiveRecord::StatementInvalid, /chk_carts_client_or_session/)
    end
    
  end
end