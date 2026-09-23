class CreateBonusTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :bonus_transactions do |t|
      t.references :client, null: false, foreign_key: true
      t.references :order, null: true, foreign_key: true
      t.string :kind, null: false          # 'earn' | 'spend'
      t.integer :amount, null: false       # всегда положительное
      t.string :description, null: false   # "Заказ #1234" / "Оплата бонусами заказа #1234"

      t.timestamps
    end

    add_index :bonus_transactions, [:client_id, :created_at]
    add_index :bonus_transactions, :kind
  end
end
