# frozen_string_literal: true

# 웹 페이지 컨트롤러용 세션 인증 concern
# PagesController, ReportsController, ChannelsController에서 공유
module WebAuthenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_web_user, :logged_in?
  end

  private

  def current_web_user
    return @current_web_user if defined?(@current_web_user)

    token = session[:session_token] || cookies[:session_token]
    return @current_web_user = nil unless token

    web_session = Session.includes(:user).find_by_token(token)
    @current_web_user = web_session&.user&.then { |u| u.is_active ? u : nil }
  end

  def logged_in?
    current_web_user.present?
  end
end
