# frozen_string_literal: true

# @TASK P0-T0.4 - Email OTP 인증을 위한 컬럼 추가
# @SPEC docs/planning/02-trd.md#인증-API
# otp_code: 6자리 OTP 코드 저장
# otp_sent_at: OTP 발송 시각 (만료 검사용, 5분)
# password_digest: OTP 전용 사용자는 비밀번호 없이 가입 가능하도록 null 허용
class AddOtpToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_code, :string
    add_column :users, :otp_sent_at, :datetime
    # password_digest 는 CreateUsers 마이그레이션에서 이미 nullable 로 설정됨
  end
end
