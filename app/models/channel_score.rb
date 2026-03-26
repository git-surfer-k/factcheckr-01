# frozen_string_literal: true

# @TASK P0-T0.3 - 채널 점수 이력 모델
# @SPEC docs/planning/04-database-design.md#26-channel_scores-채널-점수-이력
# 채널별 신뢰도 점수 추이를 기록 및 조회하는 모델
class ChannelScore < ApplicationRecord
  belongs_to :channel

  validates :channel_id, presence: true

  scope :recent, -> { order(recorded_at: :desc) }
  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  scope :in_date_range, ->(start_date, end_date) { where(recorded_at: start_date..end_date) }
end
