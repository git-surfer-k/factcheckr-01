# frozen_string_literal: true

# @TASK P0-T0.3 - 채널 점수 이력 모델
# @TASK P3-R2-T1 - scope 보강 (recent, by_period)
# @SPEC docs/planning/04-database-design.md#26-channel_scores-채널-점수-이력
# 채널별 신뢰도 점수 추이를 기록 및 조회하는 모델
class ChannelScore < ApplicationRecord
  belongs_to :channel

  validates :channel_id, presence: true

  # 최근 순 정렬 (recorded_at 내림차순)
  scope :recent, -> { order(recorded_at: :desc) }
  # 시간순 정렬 (recorded_at 오름차순, 추이 그래프용)
  scope :chronological, -> { order(recorded_at: :asc) }
  # 특정 채널의 점수만 조회
  scope :by_channel, ->(channel_id) { where(channel_id: channel_id) }
  # 기간별 필터 (start_date ~ end_date)
  scope :by_period, ->(start_date, end_date) { where(recorded_at: start_date..end_date) }
  # by_period의 별칭 (하위 호환)
  scope :in_date_range, ->(start_date, end_date) { by_period(start_date, end_date) }
end
