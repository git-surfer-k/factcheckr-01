# frozen_string_literal: true

require "net/http"
require "json"

# Resend API를 통한 이메일 발송 커스텀 delivery method
# 발송 시점에 AdminSetting에서 최신 API 키를 조회한다.
class ResendDelivery
  RESEND_API_URL = "https://api.resend.com/emails"

  def initialize(_settings = {}); end

  def deliver!(mail)
    api_key = AdminSetting.get("resend_api_key", ENV["RESEND_API_KEY"])
    from = AdminSetting.get("resend_from_email", "FactCheckr <onboarding@resend.dev>")

    if api_key.blank?
      Rails.logger.warn "[Resend] API 키 미설정 — 이메일 발송 건너뜀"
      return
    end

    # multipart 메일에서 본문 추출
    html_body = mail.html_part&.body&.to_s
    html_body ||= mail.body.to_s if mail.content_type&.include?("text/html")
    text_body = mail.text_part&.body&.to_s
    text_body ||= mail.body.to_s unless html_body

    payload = { from: from, to: Array(mail.to), subject: mail.subject }
    payload[:html] = html_body if html_body.present?
    payload[:text] = text_body if text_body.present?
    payload[:text] = mail.subject if payload[:html].blank? && payload[:text].blank?

    response = Net::HTTP.post(
      URI(RESEND_API_URL),
      payload.to_json,
      { "Authorization" => "Bearer #{api_key}", "Content-Type" => "application/json" }
    )

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "[Resend] 발송 성공: #{mail.to&.join(', ')}"
    else
      Rails.logger.error "[Resend] 발송 실패: #{response.code} - #{response.body}"
    end
  end
end
