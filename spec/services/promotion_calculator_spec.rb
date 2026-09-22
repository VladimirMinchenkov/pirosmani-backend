# spec/services/promotion_calculator_spec.rb
require 'rails_helper'

RSpec.describe PromotionCalculator do
  let(:menu_item) { create(:menu_item, name: "Хачапури", price: 14.00) }
  let(:menu_item2) { create(:menu_item, name: "Хинкали", price: 2.50) }
  let(:menu_item3) { create(:menu_item, name: "Лимонад", price: 8.00) }

  before do
    AppSetting.find_or_create_by(key: 'pickup_discount_percent') { |s| s.value = '15' }
  end

  # ============================================================
  # 1. Базовый расчёт без скидок
  # ============================================================
  describe "базовый расчёт без скидок" do
    it "возвращает полную стоимость" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 2, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items).calculate
      expect(result.subtotal).to eq(28.00)
      expect(result.total).to eq(28.00)
      expect(result.item_discount).to eq(0)
    end
  end

  # ============================================================
  # 2. Персональная скидка (Promotion)
  # ============================================================
  describe "персональная скидка (Promotion)" do
    before do
      Promotion.create!(menu_item: menu_item, discount_type: 'percent', discount_value: 15, active: true)
    end

    it "применяет процентную скидку к блюду" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items).calculate
      expect(result.items.first[:discounted_price]).to eq(11.90)
      expect(result.item_discount).to eq(2.10)
    end

    it "не применяет скидку к комбо-товару" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: true }
      ]
      result = described_class.new(items).calculate
      expect(result.items.first[:discounted_price]).to eq(menu_item.price)
      expect(result.items.first[:discount_type]).to eq(:combo)
    end
  end

  describe "фиксированная скидка (Promotion)" do
    before do
      Promotion.create!(menu_item: menu_item, discount_type: 'fixed', discount_value: 5.00, active: true)
    end

    it "применяет фиксированную скидку" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items).calculate
      expect(result.items.first[:discounted_price]).to eq(9.00)
      expect(result.item_discount).to eq(5.00)
    end

  end

  # ============================================================
  # 3. Комбо-наборы
  # ============================================================
  describe "комбо-наборы" do
    it "фиксирует цену комбо-товара без дополнительных скидок" do
      Promotion.create!(menu_item: menu_item, discount_type: 'percent', discount_value: 50, active: true)
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: 10.00, combo_item: true }
      ]
      result = described_class.new(items).calculate
      expect(result.items.first[:discounted_price]).to eq(10.00)
      expect(result.items.first[:discount_type]).to eq(:combo)
    end
  end

  # ============================================================
  # 4. Промокоды
  # ============================================================
  describe "промокоды" do
    let(:promo_code) { create(:promo_code, code: 'TEST10', discount_type: 'percent', discount_value: 10, active: true) }

    it "применяет процентный промокод только к обычным товарам" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items, promo_code: promo_code).calculate
      expect(result.promo_code_discount).to be > 0
      expect(result.total).to be < result.subtotal
    end

    it "не применяет промокод к комбо-товарам" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: true }
      ]
      result = described_class.new(items, promo_code: promo_code).calculate
      expect(result.promo_code_discount).to eq(0)
    end

    it "не применяет промокод к товарам с персональной скидкой" do
      Promotion.create!(menu_item: menu_item, discount_type: 'percent', discount_value: 15, active: true)
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items, promo_code: promo_code).calculate
      expect(result.promo_code_discount).to eq(0)
    end

    context "фиксированный промокод" do
      let(:fixed_promo) { create(:promo_code, code: 'FIX5', discount_type: 'fixed', discount_value: 5.00, active: true) }

      it "ограничивает скидку стоимостью eligible товаров" do
        # Комбо 20 BYN + обычный товар 3 BYN, промокод на 5 BYN → скидка = 3 BYN
        items = [
          { menu_item_id: menu_item.id, name: "Комбо", quantity: 1, price: 20.00, combo_item: true },
          { menu_item_id: menu_item2.id, name: menu_item2.name, quantity: 1, price: 3.00, combo_item: false }
        ]
        result = described_class.new(items, promo_code: fixed_promo).calculate
        expect(result.promo_code_discount).to eq(3.00)
        # Комбо не тронуто
        expect(result.items.first[:discounted_price]).to eq(20.00)
      end
    end
  end

  # ============================================================
  # 5. Самовывоз
  # ============================================================
  describe "самовывоз" do
    it "применяет скидку к обычным товарам" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items, delivery_type: 'pickup').calculate
      expect(result.pickup_discount).to be > 0
      expect(result.items.first[:discount_type]).to eq(:pickup)
    end

    it "не применяет скидку к комбо-товарам" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: true }
      ]
      result = described_class.new(items, delivery_type: 'pickup').calculate
      expect(result.pickup_discount).to eq(0)
    end

    it "не применяет скидку к товарам с персональной скидкой" do
      Promotion.create!(menu_item: menu_item, discount_type: 'percent', discount_value: 15, active: true)
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items, delivery_type: 'pickup').calculate
      expect(result.pickup_discount).to eq(0)
    end

    it "не применяет скидку к товарам с промокодом" do
      promo = create(:promo_code, code: 'TEST10', discount_type: 'percent', discount_value: 10, active: true)
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items, delivery_type: 'pickup', promo_code: promo).calculate
      # Промокод применился, самовывоз — нет
      expect(result.promo_code_discount).to be > 0
      expect(result.pickup_discount).to eq(0)
    end

    it "читает процент из AppSetting" do
      AppSetting.find_by(key: 'pickup_discount_percent').update!(value: '10')
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: 10.00, combo_item: false }
      ]
      result = described_class.new(items, delivery_type: 'pickup').calculate
      expect(result.pickup_discount).to eq(1.00)
    end
  end

  # ============================================================
  # 6. Скидка от суммы заказа (OrderPromotion)
  # ============================================================
  describe "скидка от суммы заказа" do
    before do
      OrderPromotion.create!(min_amount: 50, discount_type: 'percent', discount_value: 10, active: true)
    end

    it "применяется при достижении min_amount" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 4, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items).calculate
      expect(result.order_discount).to be > 0
    end

    it "не применяется если сумма меньше min_amount" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items).calculate
      expect(result.order_discount).to eq(0)
    end
  end

  # ============================================================
  # 7. Приоритет скидок (непересечение)
  # ============================================================
  describe "приоритет скидок" do
    before do
      Promotion.create!(menu_item: menu_item, discount_type: 'percent', discount_value: 20, active: true)
    end

    it "комбо > промо: комбо-товар не получает персональную скидку" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: true }
      ]
      result = described_class.new(items).calculate
      expect(result.items.first[:discount_type]).to eq(:combo)
      expect(result.items.first[:discounted_price]).to eq(menu_item.price)
    end

    it "промо > самовывоз: товар с персональной скидкой не получает скидку самовывоза" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false }
      ]
      result = described_class.new(items, delivery_type: 'pickup').calculate
      expect(result.items.first[:discount_type]).to eq(:promotion)
      expect(result.pickup_discount).to eq(0)
    end

    it "промокод > самовывоз: товар с промокодом не получает скидку самовывоза" do
      promo = create(:promo_code, code: 'TEST10', discount_type: 'percent', discount_value: 10, active: true)
      items = [
        { menu_item_id: menu_item2.id, name: menu_item2.name, quantity: 1, price: menu_item2.price, combo_item: false }
      ]
      result = described_class.new(items, delivery_type: 'pickup', promo_code: promo).calculate
      expect(result.promo_code_discount).to be > 0
      expect(result.pickup_discount).to eq(0)
    end
  end

  # ============================================================
  # 8. Смешанная корзина
  # ============================================================
  describe "смешанная корзина" do
    before do
      Promotion.create!(menu_item: menu_item, discount_type: 'percent', discount_value: 15, active: true)
      OrderPromotion.create!(min_amount: 30, discount_type: 'percent', discount_value: 5, active: true)
    end

    it "корректно считает смешанную корзину (комбо + промо + обычный)" do
      items = [
        { menu_item_id: menu_item.id, name: menu_item.name, quantity: 1, price: menu_item.price, combo_item: false },
        { menu_item_id: menu_item2.id, name: menu_item2.name, quantity: 2, price: menu_item2.price, combo_item: true },
        { menu_item_id: menu_item3.id, name: menu_item3.name, quantity: 1, price: menu_item3.price, combo_item: false }
      ]
      result = described_class.new(items).calculate
      # Хачапури: 14.00 - 15% = 11.90
      expect(result.items[0][:discounted_price]).to eq(11.90)
      # Хинкали (комбо): без скидки
      expect(result.items[1][:discounted_price]).to eq(2.50)
      # Лимонад: полная цена
      expect(result.items[2][:discounted_price]).to eq(8.00)
      # subtotal = 11.90 + 5.00 + 8.00 = 24.90
      expect(result.subtotal).to eq(24.90)
    end
  end
end