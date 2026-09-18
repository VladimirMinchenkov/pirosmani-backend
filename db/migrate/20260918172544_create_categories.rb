class CreateCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :icon
      t.integer :position, default: 0
      t.timestamps
    end

    add_column :menu_items, :category_id, :bigint
    add_foreign_key :menu_items, :categories
    add_index :menu_items, :category_id
  end
end
