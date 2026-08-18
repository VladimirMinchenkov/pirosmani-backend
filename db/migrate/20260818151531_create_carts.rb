class CreateCarts < ActiveRecord::Migration[7.0]
  def change
    create_table :carts do |t|
      t.references :client, optional: true, null: false, foreign_key: true
      t.string :session_id
      t.integer :status

      t.timestamps
    end
  end
end
