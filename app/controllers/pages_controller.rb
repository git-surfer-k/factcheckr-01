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

  # 홈 페이지: 로그인 시 내 팩트체크, 비로그인 시 전체 최근 팩트체크 표시
  def home
    @recent_checks = if logged_in?
      current_web_user.fact_checks.includes(:channel).order(created_at: :desc).limit(12)
    else
      FactCheck.includes(:channel).where(status: :completed).order(created_at: :desc).limit(12)
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

  # @TASK P4-S1-T1 - 내 기록 화면 UI 구현
  # 내 팩트체크 기록 페이지
  # 미인증 사용자는 홈으로 리다이렉트한다.
  # @fact_checks: 로그인 사용자의 팩트체크 기록 (최신순, 페이지당 20건)
  # @has_next_page: 다음 페이지 존재 여부 (페이지네이션 UI에 사용)
  def history
    unless logged_in?
      redirect_to root_path and return
    end

    @page = (params[:page] || 1).to_i
    @per_page = 20
    # includes(:channel)으로 N+1 쿼리 방지 (채널명 표시에 필요)
    all_checks = current_web_user.fact_checks
                                 .includes(:channel)
                                 .order(created_at: :desc)
                                 .offset((@page - 1) * @per_page)
                                 .limit(@per_page + 1)
                                 .to_a

    # 다음 페이지 존재 여부: limit+1 트릭으로 추가 쿼리 없이 확인
    @has_next_page = all_checks.length > @per_page
    @fact_checks = all_checks.first(@per_page)
  end

  # 설정 페이지: 로그인 필수, 사용자 프로필 + 구독 정보 로드
  def settings
    # 비로그인 시 인증 페이지로 리다이렉트
    unless logged_in?
      redirect_to auth_path
      return
    end

    # 현재 활성 구독 조회 (없으면 nil)
    @current_subscription = current_web_user.subscriptions.active.order(created_at: :desc).first
  end

  # 로그인/회원가입 페이지 (Email OTP)
  def auth
    # 이미 로그인한 사용자는 홈으로 리다이렉트
    redirect_to root_path and return if logged_in?
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
