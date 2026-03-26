# @TASK P2-R4-T1 - 분석 API 라우터
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
# @TEST ai_server/tests/test_pipeline.py
#
# POST /api/analyze — 영상 분석 요청
# GET /api/analyze/{task_id}/status — 분석 상태 조회

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, HTTPException

from models.schemas import (
    AnalyzeRequest,
    AnalyzeResponse,
    ErrorResponse,
    StatusResponse,
)
from services.pipeline import AnalysisPipeline, TaskStore

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["analyze"])

# 전역 태스크 저장소와 파이프라인 인스턴스
# (앱 시작 시 main.py에서 초기화할 수도 있지만, 단순화를 위해 모듈 레벨에서 생성)
task_store = TaskStore()
pipeline = AnalysisPipeline(task_store=task_store)


def get_task_store() -> TaskStore:
    """태스크 저장소를 반환합니다. (테스트에서 교체 가능)"""
    return task_store


def get_pipeline() -> AnalysisPipeline:
    """파이프라인을 반환합니다. (테스트에서 교체 가능)"""
    return pipeline


@router.post(
    "/analyze",
    response_model=AnalyzeResponse,
    responses={400: {"model": ErrorResponse}},
    summary="영상 분석 요청",
    description="유튜브 URL을 받아 AI 팩트체크 분석을 시작합니다.",
)
async def analyze_video(request: AnalyzeRequest) -> AnalyzeResponse:
    """
    영상 분석을 비동기로 시작합니다.
    태스크 ID를 반환하며, 상태는 별도 API로 조회합니다.
    """
    # 간단한 URL 유효성 검사
    url = request.youtube_url.strip()
    if not url:
        raise HTTPException(
            status_code=400,
            detail={"error": "유튜브 URL이 비어있습니다.", "code": "EMPTY_URL"},
        )

    if "youtube.com" not in url and "youtu.be" not in url:
        raise HTTPException(
            status_code=400,
            detail={"error": "유효한 유튜브 URL이 아닙니다.", "code": "INVALID_URL"},
        )

    # 태스크 생성
    current_pipeline = get_pipeline()
    current_store = get_task_store()
    task_status = current_store.create_task()

    logger.info("분석 요청 접수: task_id=%s, url=%s", task_status.task_id, url)

    # 비동기로 파이프라인 실행 (BackgroundTasks 대신 asyncio.create_task 사용)
    asyncio.create_task(current_pipeline.run(task_status.task_id, url))

    return AnalyzeResponse(
        task_id=task_status.task_id,
        status=task_status.status,
        message="분석이 시작되었습니다.",
    )


@router.get(
    "/analyze/{task_id}/status",
    response_model=StatusResponse,
    responses={404: {"model": ErrorResponse}},
    summary="분석 상태 조회",
    description="태스크 ID로 분석 진행 상태를 조회합니다.",
)
async def get_analysis_status(task_id: str) -> StatusResponse:
    """태스크의 현재 상태를 반환합니다."""
    current_store = get_task_store()
    task_status = current_store.get_task(task_id)

    if task_status is None:
        raise HTTPException(
            status_code=404,
            detail={"error": "해당 태스크를 찾을 수 없습니다.", "code": "TASK_NOT_FOUND"},
        )

    return task_status
