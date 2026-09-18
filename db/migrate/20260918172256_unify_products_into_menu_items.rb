class UnifyProductsIntoMenuItems < ActiveRecord::Migration[7.0]
  def up
    # 1. Добавляем menu_item_id в cart_items (пока nullable)
    add_column :cart_items, :menu_item_id, :bigint
    add_foreign_key :cart_items, :menu_items

    # 2. Если бы были данные, мы бы перенесли их, но cart_items пустые, поэтому пропускаем

    # 3. Удаляем уникальный индекс на (cart_id, product_id)
    remove_index :cart_items, name: :idx_cart_items_cart_product_unique

    # 4. Удаляем foreign key constraint на products
    remove_foreign_key :cart_items, :products

    # 5. Удаляем столбец product_id
    remove_column :cart_items, :product_id

    # 6. Создаём новый уникальный индекс на (cart_id, menu_item_id)
    add_index :cart_items, [:cart_id, :menu_item_id], unique: true, name: :idx_cart_items_cart_menu_item_unique

    # 7. Удаляем таблицу products
    drop_table :products
  end

  def down
    # Восстанавливаем таблицу products (без данных)
    create_table :products do |t|
      t.string :name
      t.decimal :price
      t.text :description
      t.timestamps
    end

    # Восстанавливаем столбец product_id в cart_items
    add_column :cart_items, :product_id, :bigint
    add_foreign_key :cart_items, :products

    # Удаляем новый уникальный индекс
    remove_index :cart_items, name: :idx_cart_items_cart_menu_item_unique

    # Восстанавливаем старый уникальный индекс
    add_index :cart_items, [:cart_id, :product_id], unique: true, name: :idx_cart_items_cart_product_unique

    # Удаляем menu_item_id и его foreign key
    remove_foreign_key :cart_items, :menu_items
    remove_column :cart_items, :menu_item_id
  end
end
