# frozen_string_literal: true

# @TASK P0-T0.3 - 근거 뉴스 모델
# @SPEC docs/planning/04-database-design.md#25-news_sources-근거-뉴스
# 팩트체크 근거로 사용된 뉴스 기사 정보를 관리하는 모델
class NewsSource < ApplicationRecord
  belongs_to :claim

  validates :claim_id, presence: true

  scope :recent, -> { order(published_at: :desc) }
  scope :by_claim, ->(claim_id) { where(claim_id: claim_id) }
  scope :highly_relevant, -> { where("relevance_score >= ?", 0.7) }
end
