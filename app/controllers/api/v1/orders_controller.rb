# app/controllers/api/v1/orders_controller.rb
module Api
  module V1
    class OrdersController < BaseController
      before_action :require_client!

      def index
        orders = current_client.orders
                                .includes(order_items: [:menu_item, :combo, :order_item_addons])
                                .order(created_at: :desc)
        render json: orders.map { |order| OrderSerializer.new(order).as_json }
      end

      def show
        order = current_client.orders
                               .includes(order_items: [:menu_item, :combo, :order_item_addons])
                               .find(params[:id])
        render json: OrderSerializer.new(order).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      end

      # GET /api/v1/orders/:id/courier_position
      # Proxy к Yandex Delivery (или мок-симуляции) для трекинга у клиента.
      # Без телефона курьера — только имя/авто/статус/координаты/ETA.
      def courier_position
        order = current_client.orders.find(params[:id])
        snapshot = YandexDeliveryTrackingService.snapshot(order)
        if snapshot
          render json: snapshot.except(:claim_id)
        else
          render json: { error: "Courier claim not created yet" }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      end

      # POST /api/v1/orders/:id/call_courier
      # Возвращает подменный (masked) номер, чтобы клиент мог позвонить курьеру
      def call_courier
        order = current_client.orders.find(params[:id])
        render json: YandexDeliveryTrackingService.call_courier(order)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Order not found" }, status: :not_found
      rescue YandexDeliveryClaimService::Error => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def create
        order = build_order

        # Проверка "кафе открыто прямо сейчас" нужна только для ASAP-заказов —
        # предзаказ на будущее (scheduled_at) не должен блокироваться тем, что
        # сейчас, например, ночь; для него своя проверка через реальные часы
        # работы на нужный день (см. validate_scheduled_at ниже)
        if order.scheduled_at.blank? && !WorkingHoursService.accepting_orders?
          return render json: { error: "Заказы не принимаются. #{WorkingHoursService.status_text}" }, status: :unprocessable_entity
        end

        delivery_price = resolve_delivery_price(order)
        return render json: { error: delivery_price[:error] }, status: delivery_price[:status] if delivery_price[:error]

        # "Живой" замер от Yandex check-price отражает трафик ПРЯМО СЕЙЧАС — это
        # релевантно только для ASAP (курьер выезжает почти сразу). Для ЛЮБОГО
        # предзаказа (даже "сегодня вечером") трафик на фактический момент
        # доставки нам неизвестен — используем усреднённую настройку, а не
        # мгновенный замер текущих условий на дороге.
        travel_minutes = effective_travel_minutes(order, delivery_price[:estimated_minutes])

        scheduled_error = validate_scheduled_at(order, travel_minutes: travel_minutes)
        return render json: { error: scheduled_error }, status: :unprocessable_entity if scheduled_error

        # Плановое время старта готовки для предзаказов (используется в админке
        # для бейджа-напоминания кухне) — раньше этот метод существовал, но
        # никогда не вызывался, из-за чего cooking_start_planned_at всегда
        # оставался nil
        assign_cooking_start_planned_at(order, travel_minutes: travel_minutes)

        order.delivery_price = delivery_price[:value]
        items_total = calculate_items_total(order_items_params) + calculate_combo_items_total(combo_items_params)
        base_total = apply_promo(items_total, order) + order.delivery_price

        # Рассчитываем списание бонусов
        bonus_points_to_use = params.dig(:order, :bonus_points_to_use).to_i
        bonus_discount = 0
        if bonus_points_to_use > 0
          max_spendable = current_client.max_spendable_bonuses(base_total)
          bonus_points_to_use = [bonus_points_to_use, max_spendable].min
          bonus_discount = (bonus_points_to_use * 0.01).round(2)
        end

        order.total_price = [base_total - bonus_discount, 0].max.round(2)
        order.bonus_points_used = bonus_points_to_use

        Order.transaction do
          order.save!
          order.promo_code&.increment_usage!
          create_order_items!(order)
          create_combo_items!(order)
          # Списываем бонусы сразу при создании заказа
          current_client.spend_bonuses!(bonus_points_to_use, order: order) if bonus_points_to_use > 0
        end

        order.reload
        # Уведомление в Telegram — best-effort, никогда не должно ронять
        # создание заказа (сбой отправки просто логируется внутри сервиса)
        TelegramOrderNotifierService.notify_new_order!(order)

        render json: OrderSerializer.new(order).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "One of the menu items or addons was not found" }, status: :not_found
      end

      private

      def require_client!
        return if current_client.present?

        render json: { error: "Authorization required" }, status: :unauthorized
      end

      def build_order
        order = Order.new(order_params)
        order.client = current_client
        order.status = "pending"

        if order.order_type_delivery?
          assign_delivery_address(order)
        end

        order
      end

      def assign_delivery_address(order)
        if params.dig(:order, :client_address_id).present?
          order.client_address = current_client.client_addresses.find(params[:order][:client_address_id])
          order.address ||= order.client_address.full_address
        end
      end

      def resolve_delivery_price(order)
        return { value: 0.0, estimated_minutes: nil } if order.order_type_pickup?

        lat = params.dig(:order, :lat)&.to_f || order.client_address&.lat&.to_f
        lng = params.dig(:order, :lng)&.to_f || order.client_address&.lng&.to_f

        # Всегда проверяем, что адрес в зоне доставки (защита от подделки estimated_cost)
        unless lat && lng && address_in_delivery_zone?(lat, lng)
          return { error: "Delivery not available here", status: :unprocessable_entity }
        end

        # Для ПРЕДЗАКАЗА цену фиксируем по стабильному тарифу зоны (задаётся
        # админом), а НЕ по "живой" котировке Yandex за текущий момент.
        # Важно: используемый тариф — "Экспресс"/курьер (b2b/cargo/integration
        # с express-профилем), а НЕ грузовой Cargo с дистанционным тарифом —
        # цена в нём динамическая, зависит от спроса/времени суток так же, как
        # у такси (тот же принцип, что и travel_minutes). Курьер физически
        # поедет не сейчас, а в другой день/час, когда фактическая стоимость
        # логистики у Yandex может отличаться от сиюминутной в разы. Бизнес
        # коммитится клиенту на цену уже при оформлении заказа, поэтому для
        # предзаказа используется предсказуемый тариф, а не рыночный курс
        # "прямо сейчас" — риск разницы фактической стоимости логистики несёт
        # кафе, а не клиент.
        if order.scheduled_at.present?
          zone = order.delivery_zone || resolve_zone_from_params(order)
          return { error: "Delivery not available here", status: :unprocessable_entity } unless zone

          order.delivery_zone = zone
          return { value: zone.price.to_f, estimated_minutes: nil }
        end

        if AppSettingsService.use_yandex_delivery?
          estimated_cost = params.dig(:order, :estimated_cost)&.to_f
          # estimated_minutes — реальное время в дороге от Yandex check-price для
          # этого конкретного адреса (фронт получает его при выборе адреса на
          # checkout). Используем для точного расчёта DeliveryTimingService,
          # вместо усреднённой настройки cafe_avg_travel_minutes. Актуально
          # только для ASAP — курьер выезжает почти сразу.
          estimated_minutes = params.dig(:order, :estimated_minutes)&.to_f
          if estimated_cost && estimated_cost > 0
            { value: estimated_cost, estimated_minutes: estimated_minutes }
          else
            result = YandexDeliveryService.calculate(lat: lat, lng: lng)
            return { error: "Delivery not available here", status: :unprocessable_entity } unless result
            { value: result[:price], estimated_minutes: result[:estimated_minutes] }
          end
        else
          zone = order.delivery_zone || resolve_zone_from_params(order)
          return { error: "Delivery not available here", status: :unprocessable_entity } unless zone

          order.delivery_zone = zone
          { value: zone.price.to_f, estimated_minutes: nil }
        end
      end

      # "Живой" замер времени в дороге от Yandex check-price отражает трафик
      # ПРЯМО СЕЙЧАС (в момент, когда клиент оформляет заказ на checkout) —
      # это релевантно только для ASAP-заказа, где курьер выезжает почти
      # немедленно. Для ЛЮБОГО предзаказа (даже "сегодня вечером", не только
      # "завтра") реальный трафик на фактический момент доставки нам неизвестен,
      # поэтому используем усреднённую настройку вместо мгновенного замера —
      # иначе, например, дневной трафик "сейчас" мог бы неверно обосновать
      # доступность/недоступность слота на завтрашний вечер.
      def effective_travel_minutes(order, live_estimate)
        if order.scheduled_at.blank?
          live_estimate.presence || AppSettingsService.avg_travel_minutes
        else
          AppSettingsService.avg_travel_minutes
        end
      end

      # Валидация предзаказа через РЕАЛЬНЫЕ часы работы кафе на конкретную
      # дату (а не наивный "Time.current + лид-тайм") — учитывает и открытие
      # кафе, и стоп-время приёма заказов, и то, что курьер должен успеть
      # доехать до закрытия. См. DeliveryTimingService#day_bounds и
      # plans/scheduled-delivery-courier-timing.md
      def validate_scheduled_at(order, travel_minutes:)
        return nil if order.scheduled_at.blank?

        bounds = DeliveryTimingService.day_bounds(
          date: order.scheduled_at.to_date,
          order_type: order.order_type,
          travel_minutes: travel_minutes
        )

        unless bounds
          return "В выбранный день кафе не работает или не успеет выполнить заказ. Пожалуйста, выберите другую дату"
        end

        if order.scheduled_at < bounds[:earliest]
          return "Выбранное время слишком близко. Минимум — #{bounds[:earliest].strftime('%d.%m %H:%M')}"
        end

        if order.scheduled_at > bounds[:latest]
          return "К этому времени мы не успеем приготовить и доставить/выдать заказ до закрытия. Пожалуйста, выберите время не позднее #{bounds[:latest].strftime('%H:%M')}"
        end

        nil
      end

      # Для предзаказов считаем, когда кухне нужно начать готовить, чтобы
      # курьер синхронно приехал к моменту готовности блюда — см.
      # DeliveryTimingService и plans/scheduled-delivery-courier-timing.md.
      # Для ASAP-заказов (без scheduled_at) не нужно — кухня начинает сразу.
      def assign_cooking_start_planned_at(order, travel_minutes:)
        return if order.scheduled_at.blank?

        order.cooking_start_planned_at = DeliveryTimingService.cooking_start_planned_at(
          target_delivery_at: order.scheduled_at,
          travel_minutes: order.order_type_delivery? ? travel_minutes : 0
        )
      end

      def address_in_delivery_zone?(lat, lng)
        DeliveryZone.active.any? { |z| z.contains_point?(lat, lng) }
      end

      def resolve_zone_from_params(order)
        lat = params.dig(:order, :lat)&.to_f || order.client_address&.lat&.to_f
        lng = params.dig(:order, :lng)&.to_f || order.client_address&.lng&.to_f
        return nil unless lat && lng

        DeliveryZone.active.find { |z| z.contains_point?(lat, lng) }
      end

      def create_order_items!(order)
        order_items_params.each do |item_params|
          menu_item = MenuItem.find(item_params[:menu_item_id])
          order_item = order.order_items.create!(
            menu_item: menu_item,
            quantity: item_params[:quantity].to_i,
            price: menu_item.price
          )

          Array(item_params[:addon_ids]).each do |addon_id|
            addon = Addon.find(addon_id)
            order_item.order_item_addons.create!(addon: addon)
          end
        end
      end

      def create_combo_items!(order)
        combo_items_params.each do |item_params|
          combo = Combo.find(item_params[:combo_id])
          order.order_items.create!(
            combo: combo,
            quantity: item_params[:quantity].to_i,
            price: combo.price
          )
        end
      end

      def calculate_items_total(items)
        items.sum do |item|
          menu_item = MenuItem.find(item[:menu_item_id])
          item_total = menu_item.price * item[:quantity].to_i

          addon_ids = Array(item[:addon_ids])
          addons_total = Addon.where(id: addon_ids).sum(:price) * item[:quantity].to_i

          item_total + addons_total
        end
      end

      def calculate_combo_items_total(items)
        items.sum do |item|
          combo = Combo.find(item[:combo_id])
          combo.price * item[:quantity].to_i
        end
      end

      def apply_promo(items_total, order)
        return items_total unless order.promo_code

        order.promo_code.apply_to(items_total)
      end

      def order_params
        params.require(:order).permit(:order_type, :address, :scheduled_at, :client_address_id, :promo_code_id)
      end

      def order_items_params
        Array(params.dig(:order, :order_items)).map do |item|
          item.permit(:menu_item_id, :quantity, addon_ids: [])
        end
      end

      def combo_items_params
        Array(params.dig(:order, :combo_items)).map do |item|
          item.permit(:combo_id, :quantity)
        end
      end
    end
  end
end
