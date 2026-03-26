# Coding Convention

> FactCheckr — 코딩 컨벤션

---

## 1. 일반 규칙

| 항목 | 규칙 |
|------|------|
| 코드 언어 | 변수명, 함수명, 클래스명 — 영어 |
| 주석 언어 | 한국어 (초보자가 이해할 수 있는 쉬운 말) |
| 커밋 메시지 | 한국어 |
| 들여쓰기 | 2 spaces (Ruby), 4 spaces (Python) |
| 줄 길이 | 최대 120자 |

---

## 2. Ruby on Rails (프론트엔드 + 백엔드)

### 2.1 네이밍

| 대상 | 규칙 | 예시 |
|------|------|------|
| 모델 | 단수 PascalCase | `FactCheck`, `Channel` |
| 컨트롤러 | 복수 PascalCase | `FactChecksController` |
| 테이블 | 복수 snake_case | `fact_checks`, `channels` |
| 메서드 | snake_case | `calculate_trust_score` |
| 변수 | snake_case | `overall_score` |
| 상수 | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 뷰 파일 | snake_case | `_claim_card.html.erb` |

### 2.2 디렉토리 구조

```
app/
├── controllers/
│   ├── fact_checks_controller.rb
│   ├── channels_controller.rb
│   ├── rankings_controller.rb
│   └── settings_controller.rb
├── models/
│   ├── user.rb
│   ├── fact_check.rb
│   ├── channel.rb
│   ├── claim.rb
│   └── subscription.rb
├── views/
│   ├── fact_checks/
│   ├── channels/
│   ├── rankings/
│   └── shared/
├── services/
│   ├── ai_analysis_service.rb
│   └── report_download_service.rb
└── jobs/
    └── fact_check_job.rb
```

### 2.3 코드 스타일

- Rubocop 기본 설정 사용
- `frozen_string_literal: true` 모든 파일에 추가
- Service Object 패턴 — 비즈니스 로직은 `app/services/`에
- Background Job — 긴 작업(AI 분석)은 `app/jobs/`에

---

## 3. Python / FastAPI (AI 서버)

### 3.1 네이밍

| 대상 | 규칙 | 예시 |
|------|------|------|
| 파일명 | snake_case | `fact_checker.py` |
| 클래스 | PascalCase | `FactChecker` |
| 함수 | snake_case | `extract_claims` |
| 변수 | snake_case | `claim_text` |
| 상수 | SCREAMING_SNAKE_CASE | `OPENAI_MODEL` |

### 3.2 디렉토리 구조

```
ai_server/
├── main.py
├── routers/
│   ├── analysis.py
│   └── report.py
├── services/
│   ├── video_downloader.py      # yt-dlp
│   ├── transcriber.py           # Whisper
│   ├── claim_extractor.py       # OpenAI API
│   ├── news_matcher.py          # 빅카인즈 API
│   ├── fact_checker.py          # 종합 검증
│   └── report_generator.py      # 리포트 생성
├── models/
│   ├── schemas.py               # Pydantic 모델
│   └── database.py              # DB 연결
├── config/
│   └── settings.py              # 환경 변수
└── tests/
    └── ...
```

### 3.3 코드 스타일

- Ruff (포맷터 + 린터) 사용
- Type hints 필수
- Pydantic v2 모델 사용
- async/await 적극 활용

---

## 4. 데이터베이스

### 4.1 테이블/컬럼 네이밍

| 대상 | 규칙 | 예시 |
|------|------|------|
| 테이블 | 복수 snake_case | `fact_checks` |
| 컬럼 | snake_case | `trust_score` |
| FK | `{테이블단수}_id` | `channel_id` |
| 인덱스 | `idx_{테이블}_{컬럼}` | `idx_channels_category` |

### 4.2 마이그레이션

- Rails의 ActiveRecord Migration 사용
- 마이그레이션 파일에 한국어 주석으로 목적 설명
- 롤백 가능한 마이그레이션 작성

---

## 5. API 규칙

### 5.1 Rails ↔ FastAPI 통신

| 항목 | 규칙 |
|------|------|
| 프로토콜 | HTTP/HTTPS |
| 형식 | JSON |
| 인증 | 내부 API Key |
| 에러 형식 | `{ "error": "message", "code": "ERROR_CODE" }` |

### 5.2 REST API 네이밍

| 동작 | HTTP | URL |
|------|------|-----|
| 팩트체크 요청 | POST | /api/v1/fact_checks |
| 리포트 조회 | GET | /api/v1/fact_checks/:id |
| 채널 목록 | GET | /api/v1/channels |
| 채널 상세 | GET | /api/v1/channels/:id |
| 랭킹 | GET | /api/v1/rankings?category=politics |

---

## 6. Git 규칙

### 6.1 브랜치

| 브랜치 | 용도 |
|--------|------|
| main | 프로덕션 |
| develop | 개발 통합 |
| feature/{기능명} | 기능 개발 |
| fix/{버그명} | 버그 수정 |

### 6.2 커밋 메시지

```
[태그] 한국어 설명

태그 종류:
- [기능] 새로운 기능 추가
- [수정] 버그 수정
- [개선] 기존 기능 개선
- [리팩토링] 코드 구조 변경
- [테스트] 테스트 추가/수정
- [문서] 문서 수정
- [설정] 설정 변경

예시:
[기능] 팩트체크 리포트 PDF 다운로드 추가
[수정] 채널 점수 계산 오류 수정
[개선] 분석 로딩 화면에 진행 단계 표시 추가
```

---

## 7. 테스트

| 항목 | 도구 |
|------|------|
| Rails 단위 테스트 | RSpec |
| Rails 통합 테스트 | RSpec + Capybara |
| Python 테스트 | pytest |
| API 테스트 | RSpec (request spec) |
