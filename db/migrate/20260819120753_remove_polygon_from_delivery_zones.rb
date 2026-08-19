class RemovePolygonFromDeliveryZones < ActiveRecord::Migration[7.0]
  def change
    remove_column :delivery_zones, :polygon
  end
end
