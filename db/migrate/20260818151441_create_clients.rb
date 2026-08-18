class CreateClients < ActiveRecord::Migration[7.0]
  def change
    create_table :clients do |t|
      t.string :phone
      t.datetime :phone_verified_at
      t.string :name

      t.timestamps
    end
    add_index :clients, :phone, unique: true
  end
end
