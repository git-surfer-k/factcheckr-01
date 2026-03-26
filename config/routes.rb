# frozen_string_literal: true

# @TASK P0-T0.4 - Email OTP 인증 라우트
# @TASK P1-R1-T1 - Users/Auth API 라우트 보강
# @TASK P1-S0-T1 - 공통 레이아웃 웹 페이지 라우트
# @TASK P2-R1-T1 - FactChecks API 라우트 추가
# @TASK P2-R2-T1 - Claims API 라우트 (fact_checks 하위 nested resource)
# @TASK P3-R1-T1 - Channels API 라우트 (목록/랭킹, 상세 조회)
# @TASK P3-R2-T1 - ChannelScores API 라우트 (channels 하위 nested resource)
# @TASK P3-R3-T1 - ChannelTags API 라우트 (channels 하위 nested resource)
Rails.application.routes.draw do
  # 웹 페이지 라우트 (PagesController)
  root "pages#home"
  get "/ranking",        to: "pages#ranking",  as: :ranking
  get "/history",        to: "pages#history",  as: :history
  get "/settings",       to: "pages#settings", as: :settings
  get "/analyze/:id",    to: "pages#analyze",  as: :analyze
  get "/reports/:id",    to: "reports#show",   as: :report
  # @TASK P3-S1-T1 - 채널 상세 웹 라우트
  get "/channels/:id",   to: "channels#show",  as: :channel

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

      # Channels (채널 목록/랭킹, 상세 조회) + 하위 ChannelScores, ChannelTags
      resources :channels, only: %i[index show] do
        resources :scores, only: [:index], controller: 'channel_scores'
        resources :tags, only: %i[index create], controller: 'channel_tags'
      end

      # Claims > NewsSources (주장별 근거 뉴스)
      resources :claims, only: [] do
        resources :news_sources, only: [:index]
      end

      # FactChecks (팩트체크 요청/조회) + 하위 Claims
      resources :fact_checks, only: %i[create show index] do
        resources :claims, only: [:index]
      end

      # Subscriptions (구독 관리)
      get 'subscriptions/current', to: 'subscriptions#current'
      resources :subscriptions, only: %i[create update destroy]
    end
  end

  # Health check
  get '/health', to: proc { [200, {}, [{ status: 'healthy' }.to_json]] }
end
