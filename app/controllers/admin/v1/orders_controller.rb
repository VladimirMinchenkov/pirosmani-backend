module Admin
  module V1
    class OrdersController < Admin::BaseController
      INCLUDES = [
        :client, :delivery_zone, :client_address, :promo_code,
        { order_items: [:menu_item, :combo, :order_item_addons] }
      ].freeze

      before_action :set_order, only: [:show, :update, :courier, :create_courier_claim, :call_courier, :cancel_courier_claim]

      def index
        orders = Order.includes(INCLUDES).order(created_at: :desc)
        render json: orders.map { |order| OrderSerializer.new(order).as_json(include_internal: true) }
      end

      def show
        render json: OrderSerializer.new(@order).as_json(include_internal: true)
      end

      def update
        # Статус — через общий OrderStatusUpdateService (та же логика, что
        # используется из Telegram-вебхука при нажатии Принять/Отклонить —
        # см. Webhooks::TelegramController), остальные поля — как раньше
        if order_params[:status].present?
          if OrderStatusUpdateService.update!(@order, status: order_params[:status])
            render json: OrderSerializer.new(@order).as_json(include_internal: true)
          else
            render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
          end
        elsif @order.update(order_params)
          render json: OrderSerializer.new(@order).as_json(include_internal: true)
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /admin/v1/orders/:id/courier
      # Статус заявки, контакты курьера, координаты (для своей карты в админке)
      def courier
        snapshot = YandexDeliveryTrackingService.snapshot(@order)
        if snapshot
          render json: snapshot.merge(courier_mode: AppSettingsService.yandex_courier_mode)
        else
          render json: { error: "Courier claim not created yet" }, status: :not_found
        end
      end

      # POST /admin/v1/orders/:id/create_courier_claim
      # Ручное создание заявки (retry), если авто-создание не сработало или заказ не delivery
      def create_courier_claim
        YandexDeliveryClaimService.create_and_accept!(@order)
        render json: YandexDeliveryTrackingService.snapshot(@order)
      rescue YandexDeliveryClaimService::Error => e
        render json: { error: e.message }, status: :service_unavailable
      end

      # POST /admin/v1/orders/:id/call_courier
      # Возвращает подменный номер (masked) для звонка курьеру
      def call_courier
        render json: YandexDeliveryTrackingService.call_courier(@order)
      rescue YandexDeliveryClaimService::Error => e
        render json: { error: e.message }, status: :service_unavailable
      end

      # POST /admin/v1/orders/:id/cancel_courier_claim
      # Отмена уже созданной заявки на курьера — нужна и для ручного
      # fire-drill теста реального Yandex-контура (создать заявку → сразу
      # отменить до приезда на точку А), и как обычная admin-функция на
      # случай реальных проблем с заказом. allow_paid=true подтверждает
      # платную отмену (курьер уже назначен/выехал).
      def cancel_courier_claim
        allow_paid = ActiveModel::Type::Boolean.new.cast(params[:allow_paid])
        YandexDeliveryClaimService.cancel!(@order, allow_paid: allow_paid)
        render json: YandexDeliveryTrackingService.snapshot(@order)
      rescue YandexDeliveryClaimService::Error => e
        render json: { error: e.message }, status: :service_unavailable
      end

      private

      def set_order
        @order = Order.includes(INCLUDES).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      end

      def order_params
        params.require(:order).permit(:status)
      end
    end
  end
end
