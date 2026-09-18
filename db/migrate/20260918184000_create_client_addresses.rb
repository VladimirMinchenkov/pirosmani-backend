# db/migrate/20260918184000_create_client_addresses.rb
class CreateClientAddresses < ActiveRecord::Migration[7.0]
  def change
    create_table :client_addresses do |t|
      t.references :client, null: false, foreign_key: true
      t.string :label
      t.string :emoji
      t.string :street, null: false
      t.string :entrance
      t.string :apt
      t.string :floor
      t.string :intercom
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6

      t.timestamps
    end
  end
end
