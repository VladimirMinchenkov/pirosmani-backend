class RemoveUniqueIndexFromCategoriesPosition < ActiveRecord::Migration[7.0]
  def change
    remove_index :categories, :position, unique: true, if_exists: true
  end
end
