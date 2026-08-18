class AddUniqueIndexToCartItems < ActiveRecord::Migration[7.0]
  def change
    add_index :cart_items, [:cart_id, :product_id], unique: true, name: "idx_cart_items_cart_product_unique"
  end
end
