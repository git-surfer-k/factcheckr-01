# frozen_string_literal: true

require "net/http"
require "json"

# @TASK ADMIN-T2 - Resend 이메일 발송 서비스
# @SPEC CLAUDE.md#Resend-이메일-통합
# Resend API를 사용하여 이메일을 발송하는 커스텀 ActionMailer delivery method.
# AdminSetting에서 API 키를 조회하고, 없으면 환경변수를 폴백으로 사용한다.
class ResendDelivery
  RESEND_API_URL = "https://api.resend.com/emails"

  def initialize(settings = {})
    @api_key = settings[:api_key] || AdminSetting.get("resend_api_key", ENV["RESEND_API_KEY"])
    @from = settings[:from] || AdminSetting.get("resend_from_email", "Factis <noreply@factis.com>")
  end

  # ActionMailer가 호출하는 발송 메서드
  def deliver!(mail)
    # API 키가 없으면 발송 스킵 (개발환경 등)
    if api_key.blank?
      Rails.logger.warn "[Resend] API 키가 설정되지 않아 이메일 발송을 건너뜁니다."
      return
    end

    # multipart 메일에서 html/text 본문 추출
    html_body = if mail.html_part
                  mail.html_part.body.to_s
                elsif mail.content_type&.include?("text/html")
                  mail.body.to_s
                end

    text_body = if mail.text_part
                  mail.text_part.body.to_s
                elsif !html_body && mail.body
                  mail.body.to_s
                end

    uri = URI(RESEND_API_URL)
    payload = {
      from: @from,
      to: Array(mail.to),
      subject: mail.subject,
    }
    payload[:html] = html_body if html_body.present?
    payload[:text] = text_body if text_body.present?
    # 둘 다 없으면 subject를 text로 폴백
    payload[:text] = mail.subject if payload[:html].blank? && payload[:text].blank?

    response = Net::HTTP.post(
      uri,
      payload.to_json,
      {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      }
    )

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "[Resend] 이메일 발송 성공: #{mail.to&.join(', ')}"
    else
      Rails.logger.error "[Resend] 이메일 발송 실패: #{response.code} - #{response.body}"
      # 발송 실패해도 예외를 던지지 않음 — OTP는 로그에서 확인 가능
    end
  end

  private

  # 발송 시점에 최신 API 키를 조회 (설정이 변경될 수 있으므로)
  def api_key
    @api_key.presence || AdminSetting.get("resend_api_key", ENV["RESEND_API_KEY"])
  end
end
