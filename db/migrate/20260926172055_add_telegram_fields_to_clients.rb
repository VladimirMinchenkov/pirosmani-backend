# Поддержка входа через Telegram Mini App (initData) наравне с телефон+OTP —
# см. plans/telegram-mini-app-plan.md, раздел 1.1.
class AddTelegramFieldsToClients < ActiveRecord::Migration[7.0]
  def change
    add_column :clients, :telegram_user_id, :bigint
    add_column :clients, :telegram_username, :string
    add_column :clients, :telegram_first_name, :string
    add_index :clients, :telegram_user_id, unique: true, where: "telegram_user_id IS NOT NULL"
  end
end
