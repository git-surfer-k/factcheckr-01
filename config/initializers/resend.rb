# frozen_string_literal: true

# @TASK ADMIN-T2 - Resend 커스텀 delivery method 등록
# ActionMailer에 :resend delivery method를 추가한다.
Rails.application.config.after_initialize do
  require_relative "../../app/services/resend_delivery"
  ActionMailer::Base.add_delivery_method :resend, ResendDelivery
end
