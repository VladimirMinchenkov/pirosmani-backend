class Client < ApplicationRecord
  has_many :client_addresses, dependent: :destroy
  has_many :orders, dependent: :nullify
  has_many :refresh_tokens, dependent: :destroy
  has_many :bonus_transactions, dependent: :destroy

  validates :phone, presence: { message: "Телефон обязателен" },
                    uniqueness: { message: "Телефон уже зарегистрирован" }

  # Начислить бонусы клиенту (вызывается когда заказ выполнен)
  # amount — количество бонусов (= floor(сумма заказа в BYN))
  def earn_bonuses!(amount, order:, description: nil)
    return if amount <= 0

    ActiveRecord::Base.transaction do
      bonus_transactions.create!(
        kind: 'earn',
        amount: amount,
        order: order,
        description: description || "Начисление за заказ ##{order.id}"
      )
      increment!(:bonus_points, amount)
    end
  end

  # Списать бонусы (вызывается при создании заказа)
  # Возвращает фактически списанное количество (может быть меньше запрошенного)
  def spend_bonuses!(amount, order:, description: nil)
    return 0 if amount <= 0

    actual = [amount, bonus_points].min
    return 0 if actual <= 0

    ActiveRecord::Base.transaction do
      bonus_transactions.create!(
        kind: 'spend',
        amount: actual,
        order: order,
        description: description || "Оплата бонусами заказа ##{order.id}"
      )
      decrement!(:bonus_points, actual)
    end

    actual
  end

  # Максимальное количество бонусов которое можно потратить на заказ
  # Не более 10% от суммы заказа (1 бонус = 0.01 BYN)
  def max_spendable_bonuses(order_total)
    max_by_rule = (order_total * 10).floor  # 10% от суммы в бонусах
    [bonus_points, max_by_rule].min
  end
end
