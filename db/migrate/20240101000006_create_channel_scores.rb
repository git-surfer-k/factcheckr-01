# frozen_string_literal: true

# @TASK P0-T0.3 - 채널 점수 이력 테이블 정의
# @SPEC docs/planning/04-database-design.md#26-channel_scores-채널-점수-이력
# channel_scores 테이블 생성: UUID PK, 채널별 신뢰도 점수 추이 기록
class CreateChannelScores < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_scores, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :channel_id, null: false
      t.decimal :score, precision: 5, scale: 2, default: 0.0
      t.decimal :accuracy_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :source_citation_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :consistency_score, precision: 5, scale: 2, default: 0.0
      t.datetime :recorded_at

      t.timestamps
    end

    add_foreign_key :channel_scores, :channels
    add_index :channel_scores, :channel_id
    add_index :channel_scores, [:channel_id, :recorded_at]
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
