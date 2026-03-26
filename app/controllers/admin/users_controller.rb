# frozen_string_literal: true

# @TASK ADMIN-T1 - 관리자 사용자 관리 컨트롤러
# @SPEC CLAUDE.md#사용자-관리
# 사용자 목록(페이지네이션), 상세 조회, 활성화/비활성화 토글 기능.
module Admin
  class UsersController < BaseController
    PER_PAGE = 20

    # GET /admin/users - 사용자 목록 (20명씩 페이지네이션)
    def index
      @page = [params[:page].to_i, 1].max
      @total_count = User.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @page = [@page, [@total_pages, 1].max].min

      @users = User.order(created_at: :desc)
                    .offset((@page - 1) * PER_PAGE)
                    .limit(PER_PAGE)
    end

    # GET /admin/users/:id - 사용자 상세
    def show
      @user = User.find(params[:id])
      @fact_checks = @user.fact_checks.includes(:channel).order(created_at: :desc).limit(20)
      @subscriptions = @user.subscriptions.order(created_at: :desc)
    end

    # PATCH /admin/users/:id/toggle_active - 활성화/비활성화 토글
    def toggle_active
      @user = User.find(params[:id])
      @user.update!(is_active: !@user.is_active)

      status_text = @user.is_active ? "활성화" : "비활성화"
      flash[:notice] = "#{@user.email} 사용자가 #{status_text}되었습니다."
      redirect_to admin_user_path(@user)
    end
  end
end
