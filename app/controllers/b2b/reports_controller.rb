# frozen_string_literal: true

# @TASK P5-S3-T1 - B2B 리포트 요청 화면 컨트롤러
# @TASK P5-S4-T1 - B2B 리포트 상세 화면 컨트롤러 추가
# @SPEC specs/screens/b2b-report-detail.yaml
# 기업 사용자가 광고적합성 리포트를 요청하거나 결과를 조회한다.
module B2b
  class ReportsController < ActionController::Base
    # CSRF 보호 활성화 (ActionController::Base 상속으로 자동 적용)
    protect_from_forgery with: :exception

    # B2B 전용 레이아웃 사용
    layout "b2b"

    # 인증 필터: 로그인 필요한 액션에 적용
    before_action :authenticate_b2b_user!, only: [:show]

    # GET /b2b/reports/new
    # 리포트 요청 폼을 렌더링한다.
    def new
      # 지원하는 타겟 카테고리 목록 (체크박스용)
      @target_categories = %w[정치 경제 사회 국제]
    end

    # GET /b2b/reports/:id
    # 리포트 상세 페이지를 렌더링한다.
    # 자신의 리포트만 볼 수 있으며, 없으면 404를 반환한다.
    def show
      # 현재 로그인 사용자의 리포트만 조회 (다른 사용자 리포트 접근 방지)
      @report = @current_b2b_user.b2b_reports.find(params[:id])

      # JSON 필드 파싱 (nil 안전 처리)
      @recommended_channels = parse_json_field(@report.recommended_channels)
      @report_data          = parse_json_field(@report.report_data)
    rescue ActiveRecord::RecordNotFound
      # 존재하지 않거나 다른 사용자 리포트는 404 응답
      render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
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

    # JSON 문자열을 안전하게 파싱하여 Ruby 객체로 반환한다.
    # 파싱 실패 시 nil을 반환한다.
    def parse_json_field(value)
      return nil if value.blank?

      JSON.parse(value)
    rescue JSON::ParserError
      nil
    end
  end
end
