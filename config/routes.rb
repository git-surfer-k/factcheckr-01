# frozen_string_literal: true

# @TASK P0-T0.4 - Email OTP 인증 라우트
# @TASK P1-R1-T1 - Users/Auth API 라우트 보강
# @TASK P1-S0-T1 - 공통 레이아웃 웹 페이지 라우트
Rails.application.routes.draw do
  # 웹 페이지 라우트 (PagesController)
  root "pages#home"
  get "/ranking",  to: "pages#ranking",  as: :ranking
  get "/history",  to: "pages#history",  as: :history
  get "/settings", to: "pages#settings", as: :settings

  namespace :api do
    namespace :v1 do
      # Authentication (Email OTP)
      post 'auth/request_otp', to: 'auth#request_otp'
      post 'auth/verify_otp', to: 'auth#verify_otp'
      delete 'auth/logout', to: 'auth#logout'

      # User profile (PUT/PATCH 모두 지원)
      get 'users/me', to: 'users#me'
      put 'users/me', to: 'users#update_me'
      patch 'users/me', to: 'users#update_me'
      delete 'users/me', to: 'users#destroy_me'

      # Subscriptions (구독 관리)
      get 'subscriptions/current', to: 'subscriptions#current'
      resources :subscriptions, only: %i[create update destroy]
    end
  end

  # Health check
  get '/health', to: proc { [200, {}, [{ status: 'healthy' }.to_json]] }
end
