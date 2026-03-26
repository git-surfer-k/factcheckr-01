# frozen_string_literal: true

# @TASK P0-T0.3 - 유튜브 채널 모델
# @TASK P3-R1-T1 - 채널 랭킹/검색 스코프 추가
# @SPEC docs/planning/04-database-design.md#22-channels-유튜브-채널
# 유튜브 채널 정보 및 신뢰도 점수를 관리하는 모델
class Channel < ApplicationRecord
  has_many :fact_checks, dependent: :destroy
  has_many :channel_scores, dependent: :destroy
  has_many :channel_tags, dependent: :destroy

  validates :youtube_channel_id, presence: true, uniqueness: true
  validates :name, presence: true

  # 카테고리별 필터
  scope :by_category, ->(category) { where(category: category) }

  # 신뢰도 점수 내림차순 정렬 (랭킹용)
  scope :ranked_by_trust, -> { order(trust_score: :desc) }

  # 이름 부분 검색 (대소문자 무시)
  scope :search_by_name, ->(query) { where("name LIKE ?", "%#{query}%") }
end
