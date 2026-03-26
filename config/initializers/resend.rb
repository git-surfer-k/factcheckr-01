# frozen_string_literal: true

# @TASK ADMIN-T2 - Resend 커스텀 delivery method 등록
# production 환경에서 Resend API를 통해 이메일을 발송한다.
# after_initialize로 지연 로드하여 빌드 시 에러를 방지한다.
Rails.application.config.after_initialize do
  require_relative "../../app/services/resend_delivery"
  ActionMailer::Base.add_delivery_method :resend, ResendDelivery

  if Rails.env.production?
    ActionMailer::Base.delivery_method = :resend
  end
end
