# frozen_string_literal: true

# @TASK ADMIN-T2 - Resend 커스텀 delivery method 등록
# ActionMailer에 :resend delivery method를 추가한다.
# production 환경에서만 활성화되며, development에서는 :log 유지.
require_relative "../../app/services/resend_delivery"
ActionMailer::Base.add_delivery_method :resend, ResendDelivery
