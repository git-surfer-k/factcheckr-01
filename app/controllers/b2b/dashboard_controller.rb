# frozen_string_literal: true

# @TASK P5-S2-T1 - B2B 대시보드 컨트롤러
# @SPEC specs/screens/b2b-dashboard.yaml
# B2B 기업 사용자의 메인 대시보드를 처리한다.
# 구독 상태와 최근 리포트 목록을 조회하여 뷰에 전달한다.
module B2b
  class DashboardController < ActionController::Base
    # CSRF 보호 활성화
    protect_from_forgery with: :exception

    # B2B 전용 레이아웃 사용
    layout "b2b"

    # 인증 필터: 모든 액션 전에 실행
    before_action :authenticate_b2b_user!

    # GET /b2b/dashboard
    # 대시보드 메인 화면을 렌더링한다.
    # - 최근 5개 리포트 목록 조회
    # - 현재 활성 구독 정보 조회
    def index
      # 최근 리포트 목록 (최신순 5개)
      @recent_reports = @current_b2b_user
        .b2b_reports
        .recent
        .limit(5)

      # 현재 활성 구독 정보
      @subscription = @current_b2b_user
        .subscriptions
        .active
        .order(created_at: :desc)
        .first
    end

    private

    # B2B 세션 쿠키로 사용자를 인증하는 필터
    # 미인증 시 B2B 로그인 페이지로 리다이렉트한다.
    def authenticate_b2b_user!
      token = cookies[:b2b_session_token]

      if token.blank?
        redirect_to b2b_login_path, alert: "로그인이 필요합니다."
        return
      end

      # 세션 레코드로 사용자 조회
      session_record = Session.find_by(token: token)

      unless session_record
        cookies.delete(:b2b_session_token)
        redirect_to b2b_login_path, alert: "세션이 만료되었습니다. 다시 로그인해 주세요."
        return
      end

      @current_b2b_user = session_record.user

      # 비활성 계정 차단
      unless @current_b2b_user&.is_active
        cookies.delete(:b2b_session_token)
        redirect_to b2b_login_path, alert: "비활성화된 계정입니다."
      end
    end
  end
end
