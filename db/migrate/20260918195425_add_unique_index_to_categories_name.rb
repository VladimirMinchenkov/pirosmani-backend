class AddUniqueIndexToCategoriesName < ActiveRecord::Migration[7.0]
  def up
    # Удаляем дубликаты: оставляем запись с минимальным id для каждого name
    execute <<-SQL
      DELETE FROM categories
      WHERE id NOT IN (
        SELECT MIN(id) FROM categories GROUP BY name
      )
    SQL
    add_index :categories, :name, unique: true
  end

  def down
    remove_index :categories, :name
  end
end
