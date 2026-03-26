# @TASK P2-R4-T1 - 테스트 공통 설정
#
# pytest 공통 fixture를 정의합니다.
# FastAPI TestClient, Mock 서비스, 태스크 저장소 등을 제공합니다.

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# ai_server 디렉토리를 모듈 검색 경로에 추가
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from httpx import ASGITransport, AsyncClient

from main import app
from models.schemas import (
    AnalysisStatus,
    ClaimExtractionResult,
    DownloadResult,
    TranscriptResult,
)
from services.pipeline import AnalysisPipeline, TaskStore
from services.video_downloader import MockVideoDownloader
from services.transcriber import MockTranscriber
from services.claim_extractor import MockClaimExtractor
from services.news_matcher import MockNewsMatcher
from services.fact_checker import MockFactChecker


@pytest.fixture
def task_store() -> TaskStore:
    """빈 태스크 저장소를 생성합니다."""
    return TaskStore()


@pytest.fixture
def mock_pipeline(task_store: TaskStore) -> AnalysisPipeline:
    """모든 서비스가 Mock인 파이프라인을 생성합니다."""
    return AnalysisPipeline(
        task_store=task_store,
        downloader=MockVideoDownloader(),
        transcriber=MockTranscriber(),
        claim_extractor=MockClaimExtractor(),
        news_matcher=MockNewsMatcher(),
        fact_checker=MockFactChecker(),
    )


@pytest.fixture
def async_client():
    """FastAPI 비동기 테스트 클라이언트를 생성합니다."""
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")
