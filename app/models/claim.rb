# frozen_string_literal: true

# @TASK P0-T0.3 - 주장 검증 모델
# @SPEC docs/planning/04-database-design.md#24-claims-주장별-검증
# 영상 내 추출된 주장별 검증 결과 및 임베딩을 관리하는 모델
class Claim < ApplicationRecord
  belongs_to :fact_check
  has_many :news_sources, dependent: :destroy

  enum :verdict, { true: 0, mostly_true: 1, half_true: 2, mostly_false: 3, false: 4, unverifiable: 5 }

  validates :fact_check_id, presence: true
  validates :verdict, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_fact_check, ->(fact_check_id) { where(fact_check_id: fact_check_id) }
end
