# frozen_string_literal: true

# @TASK P0-T0.3 - 사용자 테이블 정의
# @SPEC docs/planning/04-database-design.md#21-users-사용자
# users 테이블 생성: UUID PK, 인증 정보, 사용자 유형
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    # PostgreSQL 환경에서만 pgcrypto 확장 활성화
    if postgresql?
      enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    end

    create_table :users, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :name
      t.integer :user_type, default: 0, null: false
      t.string :auth_provider
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
