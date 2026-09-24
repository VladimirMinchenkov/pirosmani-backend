class AddScheduledDeliveryTimingToOrders < ActiveRecord::Migration[7.0]
  def change
    # Плановое время начала готовки (посчитано назад от scheduled_at для предзаказов)
    add_column :orders, :cooking_start_planned_at, :datetime
    # Фактический момент, когда кухня реально перевела заказ в cooking
    add_column :orders, :cooking_started_at, :datetime
    # Плановое время вызова курьера (cooking_started_at + max(0, P - C))
    add_column :orders, :claim_planned_at, :datetime
  end
end
