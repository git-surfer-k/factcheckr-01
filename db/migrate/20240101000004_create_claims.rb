# frozen_string_literal: true

# @TASK P0-T0.3 - 주장별 검증 테이블 정의
# @SPEC docs/planning/04-database-design.md#24-claims-주장별-검증
# claims 테이블 생성: UUID PK, 주장 검증 결과 및 임베딩
class CreateClaims < ActiveRecord::Migration[8.0]
  def change
    # PostgreSQL 환경에서만 pgvector 확장 활성화
    if postgresql?
      enable_extension "vector" unless extension_enabled?("vector")
    end

    create_table :claims, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :fact_check_id, null: false
      t.text :claim_text
      t.integer :verdict, default: 0, null: false
      t.decimal :confidence, precision: 3, scale: 2, default: 0.0
      t.text :explanation
      t.integer :timestamp_start
      t.integer :timestamp_end
      if postgresql?
        t.column :embedding, :vector, limit: 1536
      else
        t.text :embedding
      end

      t.timestamps
    end

    add_foreign_key :claims, :fact_checks
    add_index :claims, :fact_check_id
    if postgresql?
      add_index :claims, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
