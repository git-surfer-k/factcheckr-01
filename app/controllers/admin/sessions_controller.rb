# frozen_string_literal: true

# @TASK ADMIN-T1 - 관리자 로그인/로그아웃 컨트롤러
# @SPEC CLAUDE.md#관리자-인증
# 환경변수(ADMIN_EMAIL, ADMIN_PASSWORD)로 관리자 계정을 인증한다.
# OTP 없이 이메일+비밀번호 방식의 단순 인증.
module Admin
  class SessionsController < BaseController
    # 로그인 페이지는 인증 불필요
    skip_before_action :require_admin!, only: [:new, :create]

    # GET /admin/login - 로그인 폼 렌더링
    def new
      # 이미 로그인된 관리자는 대시보드로 리다이렉트
      redirect_to admin_root_path if admin_logged_in?
    end

    # POST /admin/login - 로그인 처리
    def create
      admin_email = ENV.fetch("ADMIN_EMAIL", "blek.park@gmail.com")
      admin_password = ENV.fetch("ADMIN_PASSWORD", "factis-admin-2026")

      if params[:email] == admin_email && params[:password] == admin_password
        session[:admin] = true
        flash[:notice] = "관리자로 로그인되었습니다."
        redirect_to admin_root_path
      else
        flash.now[:alert] = "이메일 또는 비밀번호가 올바르지 않습니다."
        render :new, status: :unprocessable_entity
      end
    end

    # DELETE /admin/logout - 로그아웃 처리
    def destroy
      session.delete(:admin)
      flash[:notice] = "로그아웃되었습니다."
      redirect_to admin_login_path
    end
  end
end
