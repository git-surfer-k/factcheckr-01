# @TASK P2-R4-T1 - 분석 파이프라인 오케스트레이터
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# 5단계 파이프라인을 순차적으로 실행합니다:
# download -> transcribe -> extract_claims -> match_news -> fact_check
# 각 단계의 상태를 추적하고, 실패 시 에러를 기록합니다.

from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime

from models.schemas import (
    AnalysisResult,
    AnalysisStatus,
    StatusResponse,
)
from services.video_downloader import BaseVideoDownloader, MockVideoDownloader
from services.transcriber import BaseTranscriber, MockTranscriber
from services.claim_extractor import BaseClaimExtractor, MockClaimExtractor
from services.news_matcher import BaseNewsMatcher, MockNewsMatcher
from services.fact_checker import BaseFactChecker, MockFactChecker

logger = logging.getLogger(__name__)


class TaskStore:
    """
    분석 태스크 상태를 메모리에 저장합니다.
    (MVP 단계 - 추후 Redis/DB로 교체 가능)
    """

    def __init__(self) -> None:
        self._tasks: dict[str, StatusResponse] = {}

    def create_task(self) -> StatusResponse:
        """새 태스크를 생성하고 상태를 초기화합니다."""
        task_id = str(uuid.uuid4())
        now = datetime.now()
        status = StatusResponse(
            task_id=task_id,
            status=AnalysisStatus.PENDING,
            current_step="분석 대기 중",
            progress=0.0,
            created_at=now,
            updated_at=now,
        )
        self._tasks[task_id] = status
        return status

    def get_task(self, task_id: str) -> StatusResponse | None:
        """태스크 상태를 조회합니다."""
        return self._tasks.get(task_id)

    def update_task(
        self,
        task_id: str,
        *,
        status: AnalysisStatus | None = None,
        current_step: str | None = None,
        progress: float | None = None,
        result: AnalysisResult | None = None,
        error: str | None = None,
    ) -> StatusResponse | None:
        """태스크 상태를 업데이트합니다."""
        task = self._tasks.get(task_id)
        if task is None:
            return None

        if status is not None:
            task.status = status
        if current_step is not None:
            task.current_step = current_step
        if progress is not None:
            task.progress = progress
        if result is not None:
            task.result = result
        if error is not None:
            task.error = error

        task.updated_at = datetime.now()
        return task

    def list_tasks(self) -> list[StatusResponse]:
        """모든 태스크를 반환합니다."""
        return list(self._tasks.values())


# 단계별 상태 정의
PIPELINE_STEPS = [
    (AnalysisStatus.DOWNLOADING, "영상 오디오 다운로드 중", 0.1),
    (AnalysisStatus.TRANSCRIBING, "음성을 텍스트로 변환 중", 0.3),
    (AnalysisStatus.EXTRACTING, "주장 추출 중", 0.5),
    (AnalysisStatus.MATCHING, "관련 뉴스 검색 중", 0.7),
    (AnalysisStatus.VERIFYING, "팩트체크 검증 중", 0.9),
]


class AnalysisPipeline:
    """
    AI 분석 파이프라인 오케스트레이터.
    5단계를 순차적으로 실행하며 상태를 추적합니다.
    """

    def __init__(
        self,
        task_store: TaskStore,
        *,
        downloader: BaseVideoDownloader | None = None,
        transcriber: BaseTranscriber | None = None,
        claim_extractor: BaseClaimExtractor | None = None,
        news_matcher: BaseNewsMatcher | None = None,
        fact_checker: BaseFactChecker | None = None,
    ) -> None:
        self.task_store = task_store
        # 의존성 주입 (기본값: Mock 서비스)
        self.downloader = downloader or MockVideoDownloader()
        self.transcriber = transcriber or MockTranscriber()
        self.claim_extractor = claim_extractor or MockClaimExtractor()
        self.news_matcher = news_matcher or MockNewsMatcher()
        self.fact_checker = fact_checker or MockFactChecker()

    async def run(self, task_id: str, youtube_url: str) -> None:
        """
        파이프라인을 실행합니다. BackgroundTasks에서 호출됩니다.

        Args:
            task_id: 태스크 고유 ID
            youtube_url: 분석할 유튜브 URL
        """
        try:
            # 단계 1: 오디오 다운로드
            self._update_step(task_id, 0)
            download_result = await self.downloader.download_audio(youtube_url)
            logger.info("[%s] 다운로드 완료: %s", task_id[:8], download_result.video_title)

            # 단계 2: 음성 인식
            self._update_step(task_id, 1)
            transcript = await self.transcriber.transcribe(download_result.audio_path)
            logger.info("[%s] 음성 인식 완료: %d자", task_id[:8], len(transcript.text))

            # 단계 3: 주장 추출
            self._update_step(task_id, 2)
            extraction_result = await self.claim_extractor.extract_claims(transcript)
            logger.info("[%s] 주장 추출 완료: %d개", task_id[:8], extraction_result.total_count)

            # 단계 4: 뉴스 매칭
            self._update_step(task_id, 3)
            news_matches = await self.news_matcher.match_news(extraction_result)
            logger.info("[%s] 뉴스 매칭 완료: %d개 주장 처리", task_id[:8], len(news_matches))

            # 단계 5: 팩트체크 검증
            self._update_step(task_id, 4)
            analysis_result = await self.fact_checker.verify(
                extraction_result,
                news_matches,
                download_result,
            )
            logger.info("[%s] 검증 완료: 신뢰도 %.1f점", task_id[:8], analysis_result.overall_trust_score)

            # 완료
            self.task_store.update_task(
                task_id,
                status=AnalysisStatus.COMPLETED,
                current_step="분석 완료",
                progress=1.0,
                result=analysis_result,
            )
            logger.info("[%s] 파이프라인 완료", task_id[:8])

        except Exception as e:
            logger.error("[%s] 파이프라인 실패: %s", task_id[:8], str(e))
            self.task_store.update_task(
                task_id,
                status=AnalysisStatus.FAILED,
                current_step="분석 실패",
                error=str(e),
            )

    def _update_step(self, task_id: str, step_index: int) -> None:
        """파이프라인 단계를 업데이트합니다."""
        status, step_desc, progress = PIPELINE_STEPS[step_index]
        self.task_store.update_task(
            task_id,
            status=status,
            current_step=step_desc,
            progress=progress,
        )
