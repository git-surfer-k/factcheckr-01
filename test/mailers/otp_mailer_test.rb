# frozen_string_literal: true

# @TASK P0-T0.4 - OTP 메일러 테스트
# @TEST tests/mailers/otp_mailer_test.rb
require "test_helper"

class OtpMailerTest < ActionMailer::TestCase
  test "send_otp: OTP 코드가 포함된 이메일을 발송한다" do
    user = User.create!(email: "mailer-test@example.com", user_type: :b2c)
    user.generate_otp!

    email = OtpMailer.send_otp(user)

    assert_equal ["mailer-test@example.com"], email.to
    assert_includes email.subject, user.otp_code
    assert_includes email.subject, "Factis"
  end
end
