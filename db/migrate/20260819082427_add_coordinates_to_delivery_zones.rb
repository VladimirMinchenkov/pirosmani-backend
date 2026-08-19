class AddCoordinatesToDeliveryZones < ActiveRecord::Migration[7.0]
  def change
    add_column :delivery_zones, :coordinates, :jsonb, default: []
    
    # Опционально: можно добавить индекс, если будешь искать зоны по каким-то полям внутри JSON
    # add_index :delivery_zones, :coordinates, using: :gin
  end
end

