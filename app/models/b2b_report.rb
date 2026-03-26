# frozen_string_literal: true

# @TASK P0-T0.3 - B2B 광고적합성 리포트 모델
# @TASK P5-R1-T1 - status enum 보강, 유효성 검사 강화, 스코프 추가
# @SPEC docs/planning/04-database-design.md#29-b2b_reports-b2b-광고적합성-리포트
# B2B 기업용 채널 추천 리포트를 관리하는 모델
class B2bReport < ApplicationRecord
  belongs_to :user

  # status: pending(요청 대기) → analyzing(분석 중) → completed(완료) / failed(실패)
  enum :status, { pending: 0, analyzing: 1, completed: 2, failed: 3 }

  validates :user_id, presence: true
  validates :company_name, presence: true
  validates :industry, presence: true

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: :completed) }
  scope :by_status, ->(status) { where(status: status) }
end
