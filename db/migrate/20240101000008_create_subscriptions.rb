# frozen_string_literal: true

# @TASK P0-T0.3 - 구독/결제 테이블 정의
# @SPEC docs/planning/04-database-design.md#28-subscriptions-구독결제
# subscriptions 테이블 생성: UUID PK, 사용자 구독 플랜 및 결제 정보
class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :user_id, null: false
      t.integer :plan_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.datetime :started_at
      t.datetime :expires_at
      t.string :payment_method

      t.timestamps
    end

    add_foreign_key :subscriptions, :users
    add_index :subscriptions, :user_id
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
