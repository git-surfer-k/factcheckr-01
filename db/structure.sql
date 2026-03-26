CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "users" ("id" uuid DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "email" varchar NOT NULL, "password_digest" varchar, "name" varchar, "user_type" integer DEFAULT 0 NOT NULL, "auth_provider" varchar, "is_active" boolean DEFAULT TRUE NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "otp_code" varchar /*application='Factis01'*/, "otp_sent_at" datetime(6) /*application='Factis01'*/);
CREATE UNIQUE INDEX "index_users_on_email" ON "users" ("email") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "sessions" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "user_id" varchar NOT NULL, "token" varchar NOT NULL, "ip_address" varchar, "user_agent" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE UNIQUE INDEX "index_sessions_on_token" ON "sessions" ("token") /*application='Factis01'*/;
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "channels" ("id" uuid DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "youtube_channel_id" varchar NOT NULL, "name" varchar NOT NULL, "description" text, "subscriber_count" integer DEFAULT 0, "category" varchar, "trust_score" decimal(5,2) DEFAULT 0.0, "total_checks" integer DEFAULT 0, "thumbnail_url" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_channels_on_youtube_channel_id" ON "channels" ("youtube_channel_id") /*application='Factis01'*/;
CREATE INDEX "index_channels_on_category" ON "channels" ("category") /*application='Factis01'*/;
CREATE INDEX "index_channels_on_category_and_trust_score" ON "channels" ("category", "trust_score" DESC) /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "fact_checks" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "user_id" varchar NOT NULL, "channel_id" varchar NOT NULL, "youtube_video_id" varchar, "youtube_url" varchar, "video_title" varchar, "video_thumbnail" text, "transcript" text, "summary" text, "overall_score" decimal(5,2) DEFAULT 0.0, "analysis_detail" text, "status" integer DEFAULT 0 NOT NULL, "completed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_a23a003919"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_327c83bdef"
FOREIGN KEY ("channel_id")
  REFERENCES "channels" ("id")
);
CREATE INDEX "index_fact_checks_on_user_id" ON "fact_checks" ("user_id") /*application='Factis01'*/;
CREATE INDEX "index_fact_checks_on_channel_id" ON "fact_checks" ("channel_id") /*application='Factis01'*/;
CREATE INDEX "index_fact_checks_on_user_id_and_created_at" ON "fact_checks" ("user_id", "created_at" DESC) /*application='Factis01'*/;
CREATE INDEX "index_fact_checks_on_channel_id_and_created_at" ON "fact_checks" ("channel_id", "created_at" DESC) /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "claims" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "fact_check_id" varchar NOT NULL, "claim_text" text, "verdict" integer DEFAULT 0 NOT NULL, "confidence" decimal(3,2) DEFAULT 0.0, "explanation" text, "timestamp_start" integer, "timestamp_end" integer, "embedding" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_62482ca1be"
FOREIGN KEY ("fact_check_id")
  REFERENCES "fact_checks" ("id")
);
CREATE INDEX "index_claims_on_fact_check_id" ON "claims" ("fact_check_id") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "news_sources" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "claim_id" varchar NOT NULL, "title" varchar, "url" varchar, "publisher" varchar, "author" varchar, "published_at" datetime(6), "relevance_score" decimal(3,2) DEFAULT 0.0, "bigkinds_doc_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_67cb6737d3"
FOREIGN KEY ("claim_id")
  REFERENCES "claims" ("id")
);
CREATE INDEX "index_news_sources_on_claim_id" ON "news_sources" ("claim_id") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "channel_scores" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "channel_id" varchar NOT NULL, "score" decimal(5,2) DEFAULT 0.0, "accuracy_rate" decimal(5,2) DEFAULT 0.0, "source_citation_rate" decimal(5,2) DEFAULT 0.0, "consistency_score" decimal(5,2) DEFAULT 0.0, "recorded_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c61d134830"
FOREIGN KEY ("channel_id")
  REFERENCES "channels" ("id")
);
CREATE INDEX "index_channel_scores_on_channel_id" ON "channel_scores" ("channel_id") /*application='Factis01'*/;
CREATE INDEX "index_channel_scores_on_channel_id_and_recorded_at" ON "channel_scores" ("channel_id", "recorded_at") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "channel_tags" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "channel_id" varchar NOT NULL, "tag_name" varchar NOT NULL, "created_by" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_674a5c5f3b"
FOREIGN KEY ("channel_id")
  REFERENCES "channels" ("id")
, CONSTRAINT "fk_rails_910226c73d"
FOREIGN KEY ("created_by")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_channel_tags_on_channel_id" ON "channel_tags" ("channel_id") /*application='Factis01'*/;
CREATE INDEX "index_channel_tags_on_created_by" ON "channel_tags" ("created_by") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "subscriptions" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "user_id" varchar NOT NULL, "plan_type" integer DEFAULT 0 NOT NULL, "status" integer DEFAULT 0 NOT NULL, "started_at" datetime(6), "expires_at" datetime(6), "payment_method" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_933bdff476"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_subscriptions_on_user_id" ON "subscriptions" ("user_id") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "b2b_reports" ("id"  DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "user_id" varchar NOT NULL, "company_name" varchar, "industry" varchar, "product_info" text, "target_categories" text, "recommended_channels" text, "report_data" text, "status" integer DEFAULT 0 NOT NULL, "completed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_7192298768"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_b2b_reports_on_user_id" ON "b2b_reports" ("user_id") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "admin_settings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "value" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_admin_settings_on_key" ON "admin_settings" ("key") /*application='Factis01'*/;
CREATE TABLE IF NOT EXISTS "bookmarks" ("id" varchar DEFAULT (hex(randomblob(16))) NOT NULL PRIMARY KEY, "user_id" varchar NOT NULL, "fact_check_id" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c1ff6fa4ac"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_464ce074ca"
FOREIGN KEY ("fact_check_id")
  REFERENCES "fact_checks" ("id")
);
CREATE INDEX "index_bookmarks_on_user_id" ON "bookmarks" ("user_id") /*application='Factis01'*/;
CREATE UNIQUE INDEX "index_bookmarks_on_user_id_and_fact_check_id" ON "bookmarks" ("user_id", "fact_check_id") /*application='Factis01'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20240101000012'),
('20240101000011'),
('20240101000010'),
('20240101000009'),
('20240101000008'),
('20240101000007'),
('20240101000006'),
('20240101000005'),
('20240101000004'),
('20240101000003'),
('20240101000002'),
('20240101000001'),
('20240101000000');

