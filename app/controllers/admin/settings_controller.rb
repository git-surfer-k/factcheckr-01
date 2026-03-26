# frozen_string_literal: true

require "net/http"
require "json"

# @TASK ADMIN-T1 - 관리자 API 설정 관리 컨트롤러
# @TASK ADMIN-T2 - Resend 테스트 이메일 발송
# @SPEC CLAUDE.md#API-설정-관리
# 시스템 설정 조회/수정 및 Resend 테스트 이메일 발송 기능.
module Admin
  class SettingsController < BaseController
    # 관리 가능한 설정 키 목록 (화이트리스트)
    ALLOWED_KEYS = %w[
      openai_api_key openai_model
      bigkinds_api_key bigkinds_return_size bigkinds_search_days
      resend_api_key resend_from_email resend_test_email
    ].freeze

    # 민감 정보 키 (마스킹 처리 대상)
    SENSITIVE_KEYS = %w[openai_api_key bigkinds_api_key resend_api_key].freeze

    # GET /admin/settings - 설정 조회 페이지
    def show
      @settings = load_settings
      @system_status = check_system_status
    end

    # PATCH /admin/settings - 설정 업데이트
    def update
      settings_params = params.permit(settings: {})[:settings] || {}

      settings_params.each do |key, value|
        next unless ALLOWED_KEYS.include?(key.to_s)
        # 마스킹된 값(****포함)이면 변경하지 않음
        next if SENSITIVE_KEYS.include?(key.to_s) && value.include?("*")

        AdminSetting.set(key, value)
      end

      flash[:notice] = "설정이 저장되었습니다."
      redirect_to admin_settings_path
    end

    # POST /admin/settings/test_email - 테스트 이메일 발송
    def test_email
      api_key = AdminSetting.get("resend_api_key", ENV["RESEND_API_KEY"])
      from_email = AdminSetting.get("resend_from_email", "FactCheckr <noreply@gt-auto.cc>")
      admin_email = ENV.fetch("ADMIN_EMAIL", "blek.park@gmail.com")

      if api_key.blank?
        flash[:alert] = "Resend API Key가 설정되지 않았습니다."
        redirect_to admin_settings_path and return
      end

      # 테스트 수신자: Resend 테스트 모드에서는 계정 소유자 이메일만 가능
      test_to = AdminSetting.get("resend_test_email", admin_email)

      begin
        # Resend API로 직접 테스트 이메일 발송
        uri = URI("https://api.resend.com/emails")
        payload = {
          from: from_email,
          to: [test_to],
          subject: "[FactCheckr] 테스트 이메일",
          html: "<h2>FactCheckr 관리자 테스트 이메일</h2><p>이 메일이 정상적으로 수신되었다면 Resend 설정이 올바르게 구성된 것입니다.</p><p>발송 시각: #{Time.current}</p>"
        }

        response = Net::HTTP.post(
          uri,
          payload.to_json,
          {
            "Authorization" => "Bearer #{api_key}",
            "Content-Type" => "application/json"
          }
        )

        if response.is_a?(Net::HTTPSuccess)
          flash[:notice] = "테스트 이메일이 #{test_to}로 발송되었습니다."
        else
          flash[:alert] = "이메일 발송 실패: #{response.code} - #{response.body}"
        end
      rescue StandardError => e
        flash[:alert] = "이메일 발송 중 오류 발생: #{e.message}"
      end

      redirect_to admin_settings_path
    end

    private

    # 모든 설정값을 해시로 로드 (DB값 우선, 없으면 기본값)
    def load_settings
      defaults = {
        "openai_api_key" => "",
        "openai_model" => "gpt-4o",
        "bigkinds_api_key" => "",
        "bigkinds_return_size" => "10",
        "bigkinds_search_days" => "30",
        "resend_api_key" => "",
        "resend_from_email" => "FactCheckr <noreply@gt-auto.cc>"
      }

      defaults.each_with_object({}) do |(key, default), hash|
        setting = AdminSetting.find_by(key: key)
        raw_value = setting&.value || ENV[key.upcase] || default

        hash[key] = {
          value: raw_value,
          display: SENSITIVE_KEYS.include?(key) ? mask_value(raw_value) : raw_value,
          sensitive: SENSITIVE_KEYS.include?(key)
        }
      end
    end

    # 시스템 상태 확인
    def check_system_status
      {
        rails: { status: "running", detail: "Rails #{Rails.version}" },
        ai_server: check_ai_server,
        database: check_database
      }
    end

    # AI 서버 헬스체크 (localhost:8000)
    def check_ai_server
      uri = URI("http://localhost:8000/health")
      response = Net::HTTP.get_response(uri)
      { status: response.is_a?(Net::HTTPSuccess) ? "running" : "error", detail: "HTTP #{response.code}" }
    rescue StandardError => e
      { status: "offline", detail: e.message.truncate(50) }
    end

    # DB 상태 확인
    def check_database
      result = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM users")
      row = result.first
      count = row.is_a?(Hash) ? row["count"] : row[0]
      { status: "running", detail: "사용자 #{count}명" }
    rescue StandardError => e
      { status: "error", detail: e.message.truncate(50) }
    end

    # 값 마스킹 (처음 4자만 표시)
    def mask_value(value)
      return "" if value.blank?
      return value if value.length <= 4

      value[0..3] + ("*" * [value.length - 4, 16].min)
    end
  end
end
