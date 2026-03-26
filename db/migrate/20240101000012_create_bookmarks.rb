# frozen_string_literal: true

# 사용자가 리포트를 '내 기록'에 저장하는 북마크 테이블
class CreateBookmarks < ActiveRecord::Migration[8.0]
  def change
    create_table :bookmarks, id: :string, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :user_id, null: false
      t.string :fact_check_id, null: false

      t.timestamps
    end

    add_foreign_key :bookmarks, :users
    add_foreign_key :bookmarks, :fact_checks
    add_index :bookmarks, :user_id
    add_index :bookmarks, [:user_id, :fact_check_id], unique: true
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
