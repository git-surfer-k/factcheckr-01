# frozen_string_literal: true

# @TASK ADMIN-T1 - 관리자 대시보드 컨트롤러
# @SPEC CLAUDE.md#관리자-대시보드
# 전체 통계, 최근 가입 사용자, 최근 팩트체크를 표시한다.
module Admin
  class DashboardController < BaseController
    # GET /admin - 대시보드 메인 페이지
    def index
      # 전체 통계
      @total_users = User.count
      @total_fact_checks = FactCheck.count
      @total_channels = Channel.count
      @today_new_users = User.where("created_at >= ?", Time.current.beginning_of_day).count

      # 최근 가입 사용자 5명
      @recent_users = User.order(created_at: :desc).limit(5)

      # 최근 팩트체크 5건
      @recent_fact_checks = FactCheck.includes(:user, :channel).order(created_at: :desc).limit(5)
    end
  end
end
