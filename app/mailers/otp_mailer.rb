# frozen_string_literal: true

# @TASK P0-T0.4 - OTP 이메일 발송
# @SPEC docs/planning/02-trd.md#인증-API
# 개발 환경에서는 로그로 OTP 코드를 확인할 수 있음
class OtpMailer < ApplicationMailer
  # OTP 코드를 이메일로 발송
  def send_otp(user)
    @user = user
    @otp_code = user.otp_code

    # 개발 환경에서는 로그에 OTP 출력 (디버깅용)
    Rails.logger.info "[OTP] #{@user.email} 에게 발송된 OTP: #{@otp_code}"

    mail(to: @user.email, subject: "[Factis] 로그인 인증 코드: #{@otp_code}")
  end
end
