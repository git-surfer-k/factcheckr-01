# frozen_string_literal: true

# @TASK P0-T0.4 - Email OTP 인증 라우트
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication (Email OTP)
      post 'auth/request_otp', to: 'auth#request_otp'
      post 'auth/verify_otp', to: 'auth#verify_otp'
      delete 'auth/logout', to: 'auth#logout'

      # User profile
      get 'users/me', to: 'users#me'
      patch 'users/me', to: 'users#update_me'
      delete 'users/me', to: 'users#destroy_me'
    end
  end

  # Health check
  get '/health', to: proc { [200, {}, [{ status: 'healthy' }.to_json]] }
end
