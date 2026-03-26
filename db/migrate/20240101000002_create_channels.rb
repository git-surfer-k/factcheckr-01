# frozen_string_literal: true

# @TASK P0-T0.3 - 유튜브 채널 테이블 정의
# @SPEC docs/planning/04-database-design.md#22-channels-유튜브-채널
# channels 테이블 생성: UUID PK, 유튜브 채널 정보 및 신뢰도 점수
class CreateChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :channels, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :youtube_channel_id, null: false
      t.string :name, null: false
      t.text :description
      t.integer :subscriber_count, default: 0
      t.string :category
      t.decimal :trust_score, precision: 5, scale: 2, default: 0.0
      t.integer :total_checks, default: 0
      t.string :thumbnail_url

      t.timestamps
    end

    add_index :channels, :youtube_channel_id, unique: true
    add_index :channels, :category
    add_index :channels, [:category, :trust_score], order: { trust_score: "DESC" }
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
