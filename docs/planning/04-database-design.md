# Database Design

> FactCheckr — 데이터베이스 설계

---

## 1. 핵심 엔티티

```
┌─────────┐       ┌──────────────┐       ┌─────────────┐
│  User   │──1:N──│  FactCheck   │──N:1──│  Channel    │
│ (사용자) │       │ (팩트체크)    │       │  (채널)     │
└─────────┘       └──────┬───────┘       └──────┬──────┘
     │                   │                      │
     │              1:N  │                 1:N  │
     │                   ▼                      ▼
     │            ┌──────────────┐       ┌─────────────┐
     │            │    Claim     │       │ ChannelScore│
     │            │ (주장 검증)   │       │ (채널 점수)  │
     │            └──────┬───────┘       └─────────────┘
     │                   │
     │              1:N  │
     │                   ▼
     │            ┌──────────────┐
     │            │  NewsSource  │
     │            │ (근거 뉴스)   │
     │            └──────────────┘
     │
     │  1:N
     ▼
┌─────────────┐
│ Subscription│
│ (구독/결제)  │
└─────────────┘
```

---

## 2. 테이블 설계

### 2.1 users (사용자)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| email | VARCHAR(255) | 이메일 (UNIQUE) |
| name | VARCHAR(100) | 이름 (선택) |
| user_type | ENUM | b2c / b2b |
| auth_provider | VARCHAR(50) | Authentication Zero |
| created_at | TIMESTAMP | 가입일 |
| updated_at | TIMESTAMP | 수정일 |

### 2.2 channels (유튜브 채널)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| youtube_channel_id | VARCHAR(50) | 유튜브 채널 ID (UNIQUE) |
| name | VARCHAR(255) | 채널명 |
| description | TEXT | 채널 설명 |
| subscriber_count | INTEGER | 구독자 수 |
| category | VARCHAR(50) | 카테고리 (정치/경제/사회/국제) |
| trust_score | DECIMAL(5,2) | 현재 신뢰도 점수 (0~100) |
| total_checks | INTEGER | 총 팩트체크 횟수 |
| thumbnail_url | VARCHAR(500) | 채널 썸네일 |
| created_at | TIMESTAMP | 최초 등록일 |
| updated_at | TIMESTAMP | 수정일 |

### 2.3 fact_checks (팩트체크 리포트)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| user_id | UUID | FK → users |
| channel_id | UUID | FK → channels |
| youtube_video_id | VARCHAR(20) | 유튜브 영상 ID |
| youtube_url | VARCHAR(500) | 원본 URL |
| video_title | VARCHAR(500) | 영상 제목 |
| transcript | TEXT | 자막/음성 변환 텍스트 |
| summary | TEXT | 콘텐츠 요약 |
| overall_score | DECIMAL(5,2) | 종합 팩트 점수 (0~100) |
| analysis_detail | JSONB | 상세 분석 결과 |
| status | ENUM | pending / analyzing / completed / failed |
| created_at | TIMESTAMP | 생성일 |
| completed_at | TIMESTAMP | 분석 완료일 |

### 2.4 claims (주장별 검증)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| fact_check_id | UUID | FK → fact_checks |
| claim_text | TEXT | 추출된 주장 원문 |
| verdict | ENUM | true / mostly_true / half_true / mostly_false / false / unverifiable |
| confidence | DECIMAL(3,2) | AI 확신도 (0~1) |
| explanation | TEXT | 검증 설명 |
| timestamp_start | INTEGER | 영상 내 시작 시간 (초) |
| timestamp_end | INTEGER | 영상 내 종료 시간 (초) |
| embedding | vector(1536) | pgvector — 주장 임베딩 (유사 팩트 검색용) |
| created_at | TIMESTAMP | 생성일 |

### 2.5 news_sources (근거 뉴스)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| claim_id | UUID | FK → claims |
| title | VARCHAR(500) | 뉴스 제목 |
| url | VARCHAR(500) | 뉴스 URL |
| publisher | VARCHAR(100) | 언론사 |
| author | VARCHAR(100) | 기자명 |
| published_at | TIMESTAMP | 보도일 |
| relevance_score | DECIMAL(3,2) | 관련도 점수 |
| bigkinds_doc_id | VARCHAR(50) | 빅카인즈 문서 ID |

### 2.6 channel_scores (채널 점수 이력)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| channel_id | UUID | FK → channels |
| score | DECIMAL(5,2) | 해당 시점 점수 |
| accuracy_rate | DECIMAL(5,2) | 팩트체크 정확도 |
| source_citation_rate | DECIMAL(5,2) | 출처 인용률 |
| consistency_score | DECIMAL(5,2) | 논조 일관성 |
| recorded_at | TIMESTAMP | 기록 시점 |

### 2.7 channel_tags (채널 태그 — 사용자 지정)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| channel_id | UUID | FK → channels |
| tag_name | VARCHAR(50) | 태그명 |
| created_by | UUID | FK → users (태그 생성자) |
| created_at | TIMESTAMP | 생성일 |

### 2.8 subscriptions (구독/결제)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| user_id | UUID | FK → users |
| plan_type | ENUM | b2c_basic / b2c_premium / b2b_standard / b2b_enterprise |
| status | ENUM | active / canceled / expired |
| started_at | TIMESTAMP | 구독 시작일 |
| expires_at | TIMESTAMP | 만료일 |
| payment_method | VARCHAR(50) | 결제 수단 |

### 2.9 b2b_reports (B2B 광고적합성 리포트)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| user_id | UUID | FK → users (기업 계정) |
| company_name | VARCHAR(255) | 기업명 |
| industry | VARCHAR(100) | 업종 |
| product_info | TEXT | 상품/서비스 정보 |
| target_categories | VARCHAR[] | 희망 타겟 카테고리 |
| recommended_channels | JSONB | AI 추천 채널 리스트 |
| report_data | JSONB | 심층 리포트 데이터 |
| status | ENUM | pending / generating / completed |
| created_at | TIMESTAMP | 생성일 |
| completed_at | TIMESTAMP | 완료일 |

---

## 3. 인덱스 전략

| 테이블 | 인덱스 | 용도 |
|--------|--------|------|
| channels | category, trust_score DESC | 카테고리별 랭킹 조회 |
| fact_checks | user_id, created_at DESC | 내 기록 조회 |
| fact_checks | channel_id, created_at DESC | 채널별 검증 이력 |
| claims | embedding (ivfflat) | pgvector 유사 검색 |
| channel_scores | channel_id, recorded_at | 추이 그래프 |

---

## 4. ER 다이어그램 요약

```
users ──1:N── fact_checks ──N:1── channels
  │                │                  │
  │           1:N  │             1:N  │
  │                ▼                  ▼
  │             claims          channel_scores
  │                │
  │           1:N  │
  │                ▼
  │           news_sources
  │
  └──1:N── subscriptions

users ──1:N── b2b_reports (B2B 전용)
channels ──1:N── channel_tags
```
