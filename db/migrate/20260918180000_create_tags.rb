# db/migrate/20260918180000_create_tags.rb
class CreateTags < ActiveRecord::Migration[7.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end
    add_index :tags, :slug, unique: true
    add_index :tags, :name, unique: true

    create_table :menu_item_tags do |t|
      t.references :menu_item, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :menu_item_tags, [:menu_item_id, :tag_id], unique: true, name: "idx_menu_item_tags_unique"
  end
end
