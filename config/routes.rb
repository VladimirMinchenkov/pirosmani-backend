Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'phone_verifications/create'
      get 'sessions/create'
      get 'sessions/destroy'
      get 'sessions/refresh'
      get 'cart_items/create'
      get 'cart_items/update'
      get 'cart_items/destroy'
      get 'carts/show'
      get 'carts/update'
      get 'carts/destroy'
      resources :menu_items, only: [:index, :show]
      resources :orders, only: [:create, :show]
      post 'delivery_estimate', to: 'delivery_estimate#create'
      post 'delivery_zones/check', to: 'delivery_zones#check'
    end

    namespace :admin do
      post 'login', to: 'sessions#create'
      resources :delivery_zones
      resources :menu_items
      resources :orders, only: [:index, :show, :update]
    end
  end
end
