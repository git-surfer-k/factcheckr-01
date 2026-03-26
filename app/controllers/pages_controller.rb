# frozen_string_literal: true

# @TASK P1-S0-T1 - 기본 페이지 컨트롤러
# @TASK P2-S1-T1 - 홈 화면 UI 구현 (인증 연동, 최근 팩트체크 조회, analyze 라우트)
# 홈, 랭킹, 내기록, 설정, 분석 페이지를 렌더링하는 컨트롤러.
# API 컨트롤러(ActionController::API)와 다르게 뷰와 레이아웃을 지원한다.
class PagesController < ActionController::Base
  # CSRF 보호 활성화 (API가 아닌 웹 페이지이므로 필요)
  protect_from_forgery with: :exception

  # 레이아웃 명시 지정 (application.html.erb 사용)
  layout "application"

  # 홈 페이지: 인증된 사용자는 최근 팩트체크 목록을 표시
  def home
    @recent_checks = if logged_in?
      current_web_user.fact_checks.order(created_at: :desc).limit(10)
    else
      []
    end
  end

  # 채널 랭킹 페이지
  # @categories: 카테고리 탭 목록
  # @selected_category: URL 파라미터에서 선택한 카테고리 (없으면 전체)
  # @channels: 선택한 카테고리로 필터링 후 신뢰도 내림차순 정렬된 채널 목록
  def ranking
    @categories = %w[정치 경제 사회 국제]
    @selected_category = params[:category].presence

    @channels = if @selected_category.present?
      Channel.by_category(@selected_category).ranked_by_trust
    else
      Channel.ranked_by_trust
    end
  end

  # 내 팩트체크 기록 페이지
  def history
  end

  # 설정 페이지
  def settings
  end

  # 팩트체크 분석 중 페이지: /analyze/:id
  def analyze
    @fact_check_id = params[:id]
  end

  private

  # 세션 쿠키 기반으로 현재 로그인 사용자를 찾는다.
  # ApplicationController(API 전용)와 별도로 웹 세션을 처리한다.
  def current_web_user
    return @current_web_user if defined?(@current_web_user)

    token = session[:session_token] || cookies[:session_token]
    return @current_web_user = nil unless token

    web_session = Session.find_by_token(token)
    @current_web_user = web_session&.user&.then { |u| u.is_active ? u : nil }
  end

  # 로그인 상태 확인
  def logged_in?
    current_web_user.present?
  end

  # 뷰에서 current_user 헬퍼로 접근할 수 있도록 노출
  helper_method :current_web_user, :logged_in?
end
