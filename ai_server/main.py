# Factis AI 서버 — FastAPI
# 유튜브 영상 분석 및 팩트체크 파이프라인

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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


@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "ok", "service": "factis-ai"}
