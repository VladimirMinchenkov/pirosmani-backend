class Webhooks::TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    # Обработка входящих обновлений от Telegram
    render json: { status: :ok }
  end
end