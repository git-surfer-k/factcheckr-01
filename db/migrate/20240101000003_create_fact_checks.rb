# frozen_string_literal: true

# @TASK P0-T0.3 - 팩트체크 리포트 테이블 정의
# @SPEC docs/planning/04-database-design.md#23-fact_checks-팩트체크-리포트
# fact_checks 테이블 생성: UUID PK, 사용자와 채널의 팩트체크 분석 결과
class CreateFactChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :fact_checks, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :user_id, null: false
      t.string :channel_id, null: false
      t.string :youtube_video_id
      t.string :youtube_url
      t.string :video_title
      t.text :video_thumbnail
      t.text :transcript
      t.text :summary
      t.decimal :overall_score, precision: 5, scale: 2, default: 0.0
      if postgresql?
        t.jsonb :analysis_detail, default: {}
      else
        t.text :analysis_detail
      end
      t.integer :status, default: 0, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_foreign_key :fact_checks, :users
    add_foreign_key :fact_checks, :channels
    add_index :fact_checks, :user_id
    add_index :fact_checks, :channel_id
    add_index :fact_checks, [:user_id, :created_at], order: { created_at: "DESC" }
    add_index :fact_checks, [:channel_id, :created_at], order: { created_at: "DESC" }
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
