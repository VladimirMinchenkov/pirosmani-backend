class CreateArchivedCarts < ActiveRecord::Migration[7.0]
  def change
    create_table :archived_carts do |t|
      t.references :client, null: false, foreign_key: true
      t.jsonb :data
      t.string :reason

      t.timestamps
    end
  end
end
