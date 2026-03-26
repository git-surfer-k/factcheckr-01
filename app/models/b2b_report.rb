# frozen_string_literal: true

# @TASK P0-T0.3 - B2B 광고적합성 리포트 모델
# @SPEC docs/planning/04-database-design.md#29-b2b_reports-b2b-광고적합성-리포트
# B2B 기업용 채널 추천 리포트를 관리하는 모델
class B2bReport < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, generating: 1, completed: 2 }

  validates :user_id, presence: true

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: :completed) }
end
