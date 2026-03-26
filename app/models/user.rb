# frozen_string_literal: true

# @TASK P0-T0.3 - 사용자 모델
# @TASK P0-T0.4 - Email OTP 인증 지원 추가
# @SPEC docs/planning/04-database-design.md#21-users-사용자
# 인증, 구독, 팩트체크, B2B 리포트를 관리하는 메인 사용자 모델
class User < ApplicationRecord
  # OTP 전용 인증: 비밀번호는 선택 사항 (validations: false로 빈 비밀번호 허용)
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :fact_checks, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :b2b_reports, dependent: :destroy
  has_many :channel_tags, foreign_key: :created_by, dependent: :destroy

  enum :user_type, { b2c: 0, b2b: 1 }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :user_type, presence: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  scope :active, -> { where(is_active: true) }

  # OTP 만료 시간 (5분)
  OTP_EXPIRY = 5.minutes

  def active_for_authentication?
    is_active
  end

  # 6자리 OTP 코드 생성 및 발송 시각 기록
  def generate_otp!
    update!(
      otp_code: SecureRandom.random_number(100_000..999_999).to_s,
      otp_sent_at: Time.current
    )
    otp_code
  end

  # OTP 검증: 코드 일치 + 만료 시간 확인
  def verify_otp(code)
    return false if otp_code.blank? || otp_sent_at.blank?
    return false if code.to_s != otp_code
    return false if otp_sent_at < OTP_EXPIRY.ago

    # OTP 검증 성공 후 코드 무효화 (재사용 방지)
    update!(otp_code: nil, otp_sent_at: nil)
    true
  end

  # JWT 토큰 생성 (API 인증)
  def generate_jwt
    JsonWebToken.encode(user_id: id)
  end

  # 신규 세션 생성
  def create_session!
    sessions.create!
  end
end
