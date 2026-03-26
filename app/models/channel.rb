# frozen_string_literal: true

# @TASK P0-T0.3 - 유튜브 채널 모델
# @SPEC docs/planning/04-database-design.md#22-channels-유튜브-채널
# 유튜브 채널 정보 및 신뢰도 점수를 관리하는 모델
class Channel < ApplicationRecord
  has_many :fact_checks, dependent: :destroy
  has_many :channel_scores, dependent: :destroy
  has_many :channel_tags, dependent: :destroy

  validates :youtube_channel_id, presence: true, uniqueness: true
  validates :name, presence: true

  scope :by_category, ->(category) { where(category: category) }
  scope :ranked_by_trust, -> { order(trust_score: :desc) }
end
