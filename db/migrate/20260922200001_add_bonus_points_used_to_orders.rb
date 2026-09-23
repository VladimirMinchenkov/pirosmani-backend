class AddBonusPointsUsedToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :bonus_points_used, :integer, default: 0, null: false
  end
end
