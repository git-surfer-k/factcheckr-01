# frozen_string_literal: true

# @TASK P0-T0.3 - 채널 태그 테이블 정의
# @SPEC docs/planning/04-database-design.md#27-channel_tags-채널-태그-사용자-지정
# channel_tags 테이블 생성: UUID PK, 사용자 지정 채널 태그
class CreateChannelTags < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_tags, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :channel_id, null: false
      t.string :tag_name, null: false
      t.string :created_by, null: false

      t.timestamps
    end

    add_foreign_key :channel_tags, :channels
    add_foreign_key :channel_tags, :users, column: :created_by
    add_index :channel_tags, :channel_id
    add_index :channel_tags, :created_by
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
