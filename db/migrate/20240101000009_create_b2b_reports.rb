# frozen_string_literal: true

# @TASK P0-T0.3 - B2B 광고적합성 리포트 테이블 정의
# @SPEC docs/planning/04-database-design.md#29-b2b_reports-b2b-광고적합성-리포트
# b2b_reports 테이블 생성: UUID PK, B2B 기업용 채널 추천 리포트
class CreateB2bReports < ActiveRecord::Migration[8.0]
  def change
    create_table :b2b_reports, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :user_id, null: false
      t.string :company_name
      t.string :industry
      t.text :product_info
      if postgresql?
        t.string :target_categories, array: true, default: []
        t.jsonb :recommended_channels, default: {}
        t.jsonb :report_data, default: {}
      else
        t.text :target_categories
        t.text :recommended_channels
        t.text :report_data
      end
      t.integer :status, default: 0, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_foreign_key :b2b_reports, :users
    add_index :b2b_reports, :user_id
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
