# Реальная цена заявки, полученная от Yandex Delivery в момент claims/create
# (когда реально вызывается курьер) — в отличие от order.delivery_price, это
# то, что Yandex фактически спишет с кафе по итогам месяца. Расхождение между
# ними (гость платит по live-оценке check-price на чекауте, а Yandex считает
# claims/create позже, в момент реального вызова) — риск бизнеса, который
# раньше был невидим до итогового счёта от Yandex. См.
# plans/yandex-delivery-fire-drill-guide.md
class AddYandexActualClaimPriceToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :yandex_actual_claim_price, :decimal, precision: 10, scale: 2
  end
end
