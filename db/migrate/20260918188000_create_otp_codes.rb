# db/migrate/20260918188000_create_otp_codes.rb
class CreateOtpCodes < ActiveRecord::Migration[7.0]
  def change
    create_table :otp_codes do |t|
      t.string :phone, null: false
      t.string :code, null: false
      t.datetime :verified_at
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :otp_codes, [:phone, :code], unique: true
    add_index :otp_codes, :expires_at
  end
end