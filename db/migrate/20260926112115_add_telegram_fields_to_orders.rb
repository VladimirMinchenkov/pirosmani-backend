# Хранит chat_id/message_id уведомления о заказе в Telegram-канале, чтобы
# при смене статуса (Принять/Отклонить через inline-кнопки, или обычный
# PATCH из админки) редактировать ТО ЖЕ сообщение (editMessageText), а не
# слать новое. См. plans/ecosystem-architecture.md (pirosmani-telegram-orders).
class AddTelegramFieldsToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :telegram_chat_id, :string
    add_column :orders, :telegram_message_id, :bigint
  end
end
