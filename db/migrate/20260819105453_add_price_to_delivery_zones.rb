class AddPriceToDeliveryZones < ActiveRecord::Migration[7.0]
  def change
    add_column :delivery_zones, :price, :decimal
  end
end
