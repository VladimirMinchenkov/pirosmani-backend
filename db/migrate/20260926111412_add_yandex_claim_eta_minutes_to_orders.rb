# Предварительное ETA до точки Б, полученное СРАЗУ из ответа claims/create —
# можно показать клиенту ожидаемое время доставки немедленно, не дожидаясь
# вебхука performer_found/points-eta. См. plans/yandex-delivery-fire-drill-guide.md
class AddYandexClaimEtaMinutesToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :yandex_claim_eta_minutes, :integer
  end
end
