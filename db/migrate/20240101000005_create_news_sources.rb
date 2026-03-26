# frozen_string_literal: true

# @TASK P0-T0.3 - 근거 뉴스 테이블 정의
# @SPEC docs/planning/04-database-design.md#25-news_sources-근거-뉴스
# news_sources 테이블 생성: UUID PK, 팩트체크 근거 뉴스 기사
class CreateNewsSources < ActiveRecord::Migration[8.0]
  def change
    create_table :news_sources, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :claim_id, null: false
      t.string :title
      t.string :url
      t.string :publisher
      t.string :author
      t.datetime :published_at
      t.decimal :relevance_score, precision: 3, scale: 2, default: 0.0
      t.string :bigkinds_doc_id

      t.timestamps
    end

    add_foreign_key :news_sources, :claims
    add_index :news_sources, :claim_id
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
