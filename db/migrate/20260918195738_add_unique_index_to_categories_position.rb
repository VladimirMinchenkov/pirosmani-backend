class AddUniqueIndexToCategoriesPosition < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      DELETE FROM categories
      WHERE id NOT IN (
        SELECT MIN(id) FROM categories GROUP BY position
      )
    SQL
    add_index :categories, :position, unique: true
  end

  def down
    remove_index :categories, :position
  end
end
