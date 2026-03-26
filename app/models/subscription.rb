# frozen_string_literal: true

# @TASK P0-T0.3 - 구독 모델
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
end
