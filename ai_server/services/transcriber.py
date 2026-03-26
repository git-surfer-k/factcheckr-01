# @TASK P2-R4-T1 - 음성 → 텍스트 변환 서비스
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# Whisper 모델을 사용하여 오디오 파일을 텍스트로 변환합니다.
# 시간별 구간(segment) 정보도 함께 추출합니다.

from __future__ import annotations

import logging
from abc import ABC, abstractmethod

from models.schemas import TranscriptResult, TranscriptSegment
from config.settings import get_settings

logger = logging.getLogger(__name__)


class BaseTranscriber(ABC):
    """음성 인식 인터페이스"""

    @abstractmethod
    async def transcribe(self, audio_path: str) -> TranscriptResult:
        """오디오 파일을 텍스트로 변환합니다."""
        ...


class WhisperTranscriber(BaseTranscriber):
    """OpenAI Whisper를 사용한 음성 인식"""

    async def transcribe(self, audio_path: str) -> TranscriptResult:
        """
        Whisper 모델로 오디오를 텍스트로 변환합니다.

        Args:
            audio_path: 오디오 파일 경로

        Returns:
            TranscriptResult: 텍스트 변환 결과 (전체 텍스트 + 구간 정보)

        Raises:
            FileNotFoundError: 오디오 파일이 없는 경우
            RuntimeError: 변환 실패 시
        """
        import whisper

        settings = get_settings()

        try:
            logger.info("음성 인식 시작: %s (모델: %s)", audio_path, settings.whisper_model)

            # Whisper 모델 로드 및 실행
            model = whisper.load_model(settings.whisper_model)
            result = model.transcribe(audio_path, language="ko")

            # 구간 정보 변환
            segments = [
                TranscriptSegment(
                    start=seg["start"],
                    end=seg["end"],
                    text=seg["text"].strip(),
                )
                for seg in result.get("segments", [])
            ]

            transcript = TranscriptResult(
                text=result.get("text", "").strip(),
                segments=segments,
                language=result.get("language", "ko"),
            )

            logger.info("음성 인식 완료: %d개 구간, 총 %d자", len(segments), len(transcript.text))
            return transcript

        except Exception as e:
            logger.error("음성 인식 실패: %s — %s", audio_path, str(e))
            raise RuntimeError(f"음성 인식 실패: {str(e)}") from e


class MockTranscriber(BaseTranscriber):
    """테스트용 가짜 음성 인식기"""

    async def transcribe(self, audio_path: str) -> TranscriptResult:
        """테스트용 가짜 결과를 반환합니다."""
        return TranscriptResult(
            text="오늘 정부는 새로운 경제 정책을 발표했습니다. "
                 "GDP 성장률이 5%를 넘었다고 주장했습니다. "
                 "그러나 일부 전문가들은 이 수치에 의문을 제기하고 있습니다.",
            segments=[
                TranscriptSegment(start=0.0, end=10.0, text="오늘 정부는 새로운 경제 정책을 발표했습니다."),
                TranscriptSegment(start=10.0, end=20.0, text="GDP 성장률이 5%를 넘었다고 주장했습니다."),
                TranscriptSegment(start=20.0, end=30.0, text="그러나 일부 전문가들은 이 수치에 의문을 제기하고 있습니다."),
            ],
            language="ko",
        )
