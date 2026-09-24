class AddUniqueIndexToPromotionsMenuItem < ActiveRecord::Migration[7.0]
  def change
    add_index :promotions, :menu_item_id, unique: true, name: 'index_promotions_on_menu_item_id_unique'
  end
end