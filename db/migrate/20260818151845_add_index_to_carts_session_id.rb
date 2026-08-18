class AddIndexToCartsSessionId < ActiveRecord::Migration[7.0]
  def change
    add_index :carts, :session_id, if_not_exists: true
    add_index :carts, :client_id,  if_not_exists: true # если ещё не создан через references
    add_index :carts, [:client_id, :status] # составной индекс, если нужно
  end
end
