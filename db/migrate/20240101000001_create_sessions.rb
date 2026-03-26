# frozen_string_literal: true

# Rails 8 sessions migration for authentication
class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    # PostgreSQL 환경에서만 pgcrypto 확장 활성화
    if postgresql?
      enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    end

    create_table :sessions, id: :uuid, default: -> { postgresql? ? "gen_random_uuid()" : "hex(randomblob(16))" } do |t|
      t.string :user_id, null: false
      t.string :token, null: false
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_foreign_key :sessions, :users
    add_index :sessions, :token, unique: true
    add_index :sessions, :user_id
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
