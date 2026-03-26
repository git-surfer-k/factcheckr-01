# frozen_string_literal: true

# @TASK ADMIN-T1 - 관리자 인증 기본 컨트롤러
# @SPEC CLAUDE.md#관리자-인증
# 모든 관리자 컨트롤러의 부모. 세션 기반 관리자 인증을 처리한다.
# 일반 사용자(ApplicationController)와 완전히 분리된 인증 체계.
module Admin
  class BaseController < ActionController::Base
    # CSRF 보호 활성화
    protect_from_forgery with: :exception

    # 관리자 전용 레이아웃
    layout "admin"

    # 모든 관리자 페이지에 인증 필터 적용
    before_action :require_admin!

    private

    # 관리자 세션 확인. 미인증 시 로그인 페이지로 리다이렉트.
    def require_admin!
      unless admin_logged_in?
        flash[:alert] = "관리자 로그인이 필요합니다."
        redirect_to admin_login_path
      end
    end

    # 관리자 로그인 상태 확인
    def admin_logged_in?
      session[:admin] == true
    end

    helper_method :admin_logged_in?
  end
end
