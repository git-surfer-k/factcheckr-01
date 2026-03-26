# frozen_string_literal: true

# @TASK P0-T0.4 - 세션 기반 인증 헬퍼
# 세션 토큰(X-Session-Token 헤더) 기반 인증을 지원하는 베이스 컨트롤러.
# JWT 인증도 하위 호환을 위해 유지한다.
class ApplicationController < ActionController::API
  before_action :authenticate_user!

  attr_reader :current_user, :current_session

  private

  # 인증 필터: 세션 또는 JWT 토큰으로 사용자를 인증
  def authenticate_user!
    # 세션 토큰 우선 확인
    if authenticate_via_session
      return
    end

    # JWT 토큰으로 폴백
    if authenticate_via_jwt
      return
    end

    render json: { detail: "인증이 필요합니다." }, status: :unauthorized
  end

  # X-Session-Token 헤더로 세션 기반 인증
  def authenticate_via_session
    token = request.headers["X-Session-Token"]
    return false unless token

    @current_session = Session.find_by_token(token)
    return false unless @current_session

    @current_user = @current_session.user
    @current_user&.is_active
  end

  # Authorization: Bearer <token> 헤더로 JWT 인증 (하위 호환)
  def authenticate_via_jwt
    header = request.headers["Authorization"]
    return false unless header&.start_with?("Bearer ")

    token = header.split(" ").last
    decoded = JsonWebToken.decode(token)
    return false unless decoded

    @current_user = User.find_by(id: decoded[:user_id])
    @current_user&.is_active
  end
end
