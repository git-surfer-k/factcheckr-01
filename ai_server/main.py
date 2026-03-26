# @TASK P2-R4-T1 - Factis AI 서버 엔트리포인트
# @SPEC docs/planning/02-trd.md#FastAPI-AI-서버
#
# 유튜브 영상 분석 및 팩트체크 파이프라인 서버입니다.
# Rails 서버에서 HTTP로 호출하여 분석을 요청합니다.

import sys
from pathlib import Path

# ai_server 디렉토리를 모듈 검색 경로에 추가
# (uvicorn 실행 시 ai_server 내부 모듈을 찾을 수 있도록)
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.analysis import router as analysis_router

app = FastAPI(
    title="Factis AI Server",
    description="유튜브 영상 AI 팩트체크 파이프라인",
    version="0.1.0",
)

# CORS 설정 (Rails 서버와 통신)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 분석 파이프라인 라우터 등록
app.include_router(analysis_router)


@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "ok", "service": "factis-ai"}
