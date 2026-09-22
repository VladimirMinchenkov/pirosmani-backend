# app/services/promotion_calculator.rb
# Сервис расчёта скидок для заказа.
#
# Правила непересечения скидок (только ОДНА на товар):
#   1. Комбо-набор → фиксированная цена комбо
#   2. Персональная скидка (Promotion) → цена со скидкой
#   3. Промокод → только к обычным товарам (без комбо/промо)
#   4. Самовывоз → 15% скидка, только если не применились п.1-3
#   5. Полная цена
#
# Доставка исключена из базы расчёта скидок.

class PromotionCalculator
  Result = Struct.new(
    :items, :subtotal, :item_discount, :order_discount,
    :pickup_discount, :promo_code_discount, :total,
    keyword_init: true
  )

  # items: [{ menu_item_id:, name:, quantity:, price:, combo_item: false }]
  # delivery_type: 'delivery' | 'pickup'
  # promo_code: PromoCode или nil
  def initialize(items, delivery_type: 'delivery', promo_code: nil)
    @items = items
    @delivery_type = delivery_type
    @promo_code = promo_code
  end

  def calculate
    # Шаг 1: скидки на блюда (Promotion) — только для не-комбо товаров
    items_with_promo = apply_item_promotions(@items)

    # Шаг 2: промокод — только к обычным товарам (без комбо и без персональных скидок)
    promo_code_discount = apply_promo_code(items_with_promo)

    # Шаг 3: самовывоз — только к товарам без комбо/промо/промокода
    pickup_discount = apply_pickup_discount(items_with_promo)

    # Шаг 4: скидка от суммы заказа
    items_subtotal = items_with_promo.sum { |i| i[:discounted_price] * i[:quantity] }
    item_discount = items_with_promo.sum { |i| (i[:original_price] - i[:discounted_price]) * i[:quantity] }

    order_discount = apply_order_promotion(items_subtotal)

    total = [items_subtotal - order_discount - promo_code_discount - pickup_discount, 0].max

    Result.new(
      items: items_with_promo,
      subtotal: items_subtotal.round(2),
      item_discount: item_discount.round(2),
      order_discount: order_discount.round(2),
      pickup_discount: pickup_discount.round(2),
      promo_code_discount: promo_code_discount.round(2),
      total: total.round(2)
    )
  end

  private

  # Шаг 1: персональные скидки (Promotion) — только для не-комбо товаров
  def apply_item_promotions(items)
    menu_item_ids = items.reject { |i| i[:combo_item] }.map { |i| i[:menu_item_id] }.uniq
    promotions = Promotion.current.where(menu_item_id: menu_item_ids).index_by(&:menu_item_id)

    items.map do |item|
      if item[:combo_item]
        # Комбо-товар: фиксированная цена, без скидок
        item.merge(original_price: item[:price], discounted_price: item[:price], discount_type: :combo)
      else
        promo = promotions[item[:menu_item_id]]
        discounted = promo ? promo.apply(item[:price]) : item[:price]
        item.merge(
          original_price: item[:price],
          discounted_price: discounted,
          discount_type: promo ? :promotion : nil
        )
      end
    end
  end

  # Шаг 2: промокод — только к обычным товарам (без комбо и без персональных скидок)
  def apply_promo_code(items)
    return 0 unless @promo_code&.active?

    # Только товары без комбо и без персональных скидок
    eligible = items.reject { |i| i[:combo_item] || i[:discount_type] == :promotion }
    eligible_total = eligible.sum { |i| i[:discounted_price] * i[:quantity] }

    discount = case @promo_code.discount_type
               when "fixed" then [@promo_code.discount_value.to_f, eligible_total].min
               when "percent" then (eligible_total * @promo_code.discount_value / 100.0).round(2)
               else 0
               end

    # Распределяем скидку пропорционально по eligible товарам
    if discount > 0 && eligible_total > 0
      eligible.each do |item|
        share = (item[:discounted_price] * item[:quantity].to_f / eligible_total * discount).round(2)
        item[:discounted_price] = [(item[:discounted_price] * item[:quantity] - share) / item[:quantity].to_f, 0].max.round(2)
        item[:discount_type] = :promo_code
      end
    end

    discount.round(2)
  end

  # Шаг 3: самовывоз — только к товарам без комбо/промо/промокода
  def apply_pickup_discount(items)
    return 0 unless @delivery_type == 'pickup'

    setting = AppSetting.find_by(key: 'pickup_discount_percent')
    percent = setting ? setting.value.to_f : 15.0
    return 0 if percent <= 0

    eligible = items.reject { |i| i[:combo_item] || i[:discount_type] == :promotion || i[:discount_type] == :promo_code }
    eligible_total = eligible.sum { |i| i[:discounted_price] * i[:quantity] }
    discount = (eligible_total * percent / 100.0).round(2)

    if discount > 0
      multiplier = 1 - percent / 100.0
      eligible.each do |item|
        item[:discounted_price] = (item[:discounted_price] * multiplier).round(2)
        item[:discount_type] = :pickup
      end
    end

    discount
  end

  # Шаг 4: скидка от суммы заказа
  def apply_order_promotion(subtotal)
    promo = OrderPromotion.current.first
    return 0 unless promo

    promo.apply(subtotal)
  end
end