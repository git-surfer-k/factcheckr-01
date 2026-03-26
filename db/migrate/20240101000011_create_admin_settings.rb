# frozen_string_literal: true

# @TASK ADMIN-T1 - 관리자 설정 테이블
# @SPEC CLAUDE.md#관리자-페이지-구현
# Key-Value 형태로 관리자 설정을 저장하는 테이블
class CreateAdminSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_settings do |t|
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    add_index :admin_settings, :key, unique: true
  end
end
