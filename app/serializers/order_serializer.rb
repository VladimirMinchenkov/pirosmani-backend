# app/serializers/order_serializer.rb
class OrderSerializer
  def initialize(order)
    @order = order
  end

  # include_internal: true — добавляет внутренние поля, не предназначенные
  # для клиента (реальная цена заявки Yandex — внутренняя себестоимость
  # доставки, а не то, что видит гость). Используется только в admin/v1.
  def as_json(include_internal: false)
    json = {
      id: @order.id,
      status: @order.status,
      order_type: @order.order_type,
      address: @order.address,
      client_address: ClientAddressSerializer.new(@order.client_address).as_json,
      promo_code: @order.promo_code&.code,
      scheduled_at: @order.scheduled_at,
      cooking_start_planned_at: @order.cooking_start_planned_at,
      cooking_started_at: @order.cooking_started_at,
      total_price: @order.total_price.to_f,
      delivery_price: @order.delivery_price.to_f,
      bonus_points_used: @order.bonus_points_used,
      created_at: @order.created_at,
      order_items: @order.order_items.map { |oi| OrderItemSerializer.new(oi).as_json },
      # Предварительное ETA до точки Б из ответа claims/create — доступно
      # клиенту сразу после создания реальной заявки, не дожидаясь вебхука
      # (в отличие от yandex_actual_claim_price — это НЕ внутренняя себе-
      # стоимость, а полезная для гостя информация об ожидаемом времени)
      yandex_claim_eta_minutes: @order.yandex_claim_eta_minutes
    }

    if include_internal
      json[:yandex_actual_claim_price] = @order.yandex_actual_claim_price&.to_f
    end

    json
  end
end
