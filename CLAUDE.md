# FactCheckr — 유튜브 시사/뉴스 채널 AI 팩트체크 플랫폼

## 프로젝트 개요

유튜브 시사/뉴스 채널의 주장을 빅카인즈 뉴스 빅데이터(1.1억 건)로 AI 팩트체크하고,
채널 신뢰도를 평가하며, 기업에 광고적합성 리포트를 판매하는 플랫폼.

## 기술 스택

- **프론트엔드 + 백엔드**: Ruby on Rails
- **AI 서버**: FastAPI (Python) — `ai_server/`
- **데이터베이스**: PostgreSQL + pgvector
- **인증**: Authentication Zero + Email OTP
- **영상 분석**: yt-dlp → Whisper → OpenAI API → 빅카인즈 뉴스 API → OpenAI API

## 프로젝트 구조

```
factcheckr-01/
├── TASKS.md                  # 태스크 목록 (32개)
├── CLAUDE.md                 # 이 파일
├── docker-compose.yml        # PostgreSQL + pgvector
├── ai_server/                # FastAPI AI 서버
├── app/                      # Rails 앱 (MVC)
├── docs/planning/            # 기획 문서 7개
├── specs/                    # 화면 명세 14개 + 도메인 리소스
├── design/                   # 디자인 목업 (모바일 4 + 웹 4)
└── .claude/agents/           # AI 에이전트 팀
```

## 개발 규칙

- 코드(변수명, 함수명)는 영어로 작성
- 주석과 커밋 메시지는 한국어로 작성 (초보자 이해 수준)
- TDD 워크플로우: RED → GREEN → REFACTOR
- Phase 1+ 작업은 반드시 Git Worktree에서 진행

## 명령어

```bash
# Docker (PostgreSQL + pgvector)
docker compose up -d
docker compose down

# Rails 서버
bundle install
rails db:create db:migrate
rails server

# AI 서버
cd ai_server
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

## 참조 문서

- 기획: `docs/planning/01-prd.md` ~ `07-coding-convention.md`
- 화면 명세: `specs/screens/*.yaml`
- 도메인 리소스: `specs/domain/resources.yaml`
- 디자인: `design/screens/*.png`
