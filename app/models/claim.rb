# frozen_string_literal: true

# @TASK P0-T0.3 - 주장 검증 모델
# @TASK P2-R2-T1 - verdict enum 변경 및 ordered 스코프 추가
# @SPEC docs/planning/04-database-design.md#24-claims-주장별-검증
# 영상 내 추출된 주장별 검증 결과 및 임베딩을 관리하는 모델
class Claim < ApplicationRecord
  belongs_to :fact_check
  has_many :news_sources, dependent: :destroy

  # 판정 결과: unverified(미검증), true_claim(사실), mostly_true(대체로 사실),
  # half_true(절반 사실), mostly_false(대체로 거짓), false_claim(거짓)
  enum :verdict, {
    unverified: 0,
    true_claim: 1,
    mostly_true: 2,
    half_true: 3,
    mostly_false: 4,
    false_claim: 5
  }

  validates :fact_check_id, presence: true
  validates :verdict, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_fact_check, ->(fact_check_id) { where(fact_check_id: fact_check_id) }
  # 영상 타임라인 순서대로 정렬
  scope :ordered, -> { order(timestamp_start: :asc) }
end
