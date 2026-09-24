class AddCourierTrackingToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :yandex_claim_id, :string
    add_column :orders, :yandex_claim_status, :string
    add_column :orders, :courier_name, :string
    add_column :orders, :courier_vehicle, :string
    add_column :orders, :courier_phone_masked, :string
    add_column :orders, :claim_requested_at, :datetime

    add_index :orders, :yandex_claim_id
  end
end
