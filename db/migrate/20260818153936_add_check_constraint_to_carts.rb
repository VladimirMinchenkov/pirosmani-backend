class AddCheckConstraintToCarts < ActiveRecord::Migration[7.0]
  def change
    add_check_constraint :carts,
      "(client_id IS NOT NULL AND session_id IS NULL) OR (client_id IS NULL AND session_id IS NOT NULL)",
      name: "chk_carts_client_or_session"
  end
end
