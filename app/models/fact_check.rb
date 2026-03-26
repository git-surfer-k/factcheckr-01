# frozen_string_literal: true

# @TASK P0-T0.3 - 팩트체크 리포트 모델
# @SPEC docs/planning/04-database-design.md#23-fact_checks-팩트체크-리포트
# 유튜브 영상에 대한 팩트체크 분석 결과를 관리하는 모델
class FactCheck < ApplicationRecord
  belongs_to :user
  belongs_to :channel
  has_many :claims, dependent: :destroy

  enum :status, { pending: 0, analyzing: 1, completed: 2, failed: 3 }

  validates :user_id, :channel_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
end
