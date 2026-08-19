Rails.application.routes.draw do
  namespace :api do
    # Публичный API (для Next.js / мобильного клиента)
    namespace :v1 do
      # Авторизация клиента (телефон, сессии, refresh)
      resource :phone_verifications, only: [:create]
      resource :sessions, only: [:create, :destroy] do
        post :refresh, on: :collection
      end

      # Корзина и товары
      resources :carts, only: [:show, :update, :destroy]
      resources :cart_items, only: [:create, :update, :destroy]

      resources :menu_items, only: [:index, :show]
      resources :orders, only: [:create, :show]

      # Расчёт доставки: лучше GET, потому что это «получение цены по координатам», а не «создание оценки»
      get :delivery_estimate, to: 'delivery_estimate#show'
      # Если нужна сложная логика с сохранением запроса — тогда POST, но для цены достаточно GET
    end
  end

  # Админ-API (отдельный неймспейс, чтобы чётко разделить права и документацию)
  namespace :admin do
    namespace :v1 do
      # Авторизация админа
      post :login, to: 'sessions#create'

      # CRUD для админки
      resources :delivery_zones
      resources :menu_items
      resources :orders, only: [:index, :show, :update]
    end
  end
end

