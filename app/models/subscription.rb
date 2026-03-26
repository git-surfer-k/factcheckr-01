# frozen_string_literal: true

# @TASK P0-T0.3 - 구독 모델
# @TASK P1-R2-T1 - 구독 비즈니스 로직 추가
# @SPEC docs/planning/04-database-design.md#28-subscriptions-구독결제
# 사용자 구독 플랜 및 결제 정보를 관리하는 모델
class Subscription < ApplicationRecord
  belongs_to :user

  enum :plan_type, { b2c_basic: 0, b2c_premium: 1, b2b_standard: 2, b2b_enterprise: 3 }
  enum :status, { active: 0, canceled: 1, expired: 2 }

  validates :user_id, :plan_type, :status, presence: true

  scope :active, -> { where(status: :active) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :expiring_soon, ->(days = 7) { where("expires_at <= ?", Time.current + days.days) }

  # 현재 활성 상태인지 확인 (status가 active이고, 만료되지 않았는지)
  def currently_active?
    active? && !past_expiry?
  end

  # 만료 시간이 지났는지 확인
  def past_expiry?
    expires_at.present? && expires_at < Time.current
  end

  # 구독 취소 (canceled 상태로 변경)
  def cancel!
    if canceled?
      errors.add(:status, "이미 취소된 구독입니다.")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: :canceled)
  end
end
