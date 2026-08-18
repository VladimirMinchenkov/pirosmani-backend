class CreateDeliveryZones < ActiveRecord::Migration[7.0]
  def change
    create_table :delivery_zones do |t|
      t.string :name
      t.jsonb :polygon
      t.boolean :active

      t.timestamps
    end
  end
end
