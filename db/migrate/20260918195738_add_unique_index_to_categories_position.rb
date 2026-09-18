class AddUniqueIndexToCategoriesPosition < ActiveRecord::Migration[7.0]
  def change
    add_index :categories, :position, unique: true
  end
end
