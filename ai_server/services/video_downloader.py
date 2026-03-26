# @TASK P2-R4-T1 - 유튜브 오디오 다운로드 서비스
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# yt-dlp를 사용하여 유튜브 영상에서 오디오만 추출합니다.
# 실제 yt-dlp 호출은 외부 의존성이므로 인터페이스를 분리합니다.

from __future__ import annotations

import logging
import os
import uuid
from abc import ABC, abstractmethod

from models.schemas import DownloadResult
from config.settings import get_settings

logger = logging.getLogger(__name__)


class BaseVideoDownloader(ABC):
    """비디오 다운로더 인터페이스"""

    @abstractmethod
    async def download_audio(self, youtube_url: str) -> DownloadResult:
        """유튜브 URL에서 오디오를 다운로드합니다."""
        ...


class VideoDownloader(BaseVideoDownloader):
    """yt-dlp를 사용한 실제 오디오 다운로더"""

    async def download_audio(self, youtube_url: str) -> DownloadResult:
        """
        유튜브 영상에서 오디오를 추출하여 다운로드합니다.

        Args:
            youtube_url: 유튜브 영상 URL

        Returns:
            DownloadResult: 다운로드된 오디오 파일 정보

        Raises:
            ValueError: 유효하지 않은 URL인 경우
            RuntimeError: 다운로드 실패 시
        """
        import yt_dlp

        settings = get_settings()
        download_dir = settings.download_dir
        os.makedirs(download_dir, exist_ok=True)

        # 고유 파일명 생성
        file_id = str(uuid.uuid4())[:8]
        output_template = os.path.join(download_dir, f"{file_id}.%(ext)s")

        # yt-dlp 옵션: 오디오만 추출
        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": output_template,
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "wav",
                "preferredquality": "192",
            }],
            "quiet": True,
            "no_warnings": True,
        }

        try:
            logger.info("오디오 다운로드 시작: %s", youtube_url)

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(youtube_url, download=True)

            audio_path = os.path.join(download_dir, f"{file_id}.wav")

            return DownloadResult(
                audio_path=audio_path,
                video_title=info.get("title", ""),
                video_duration=float(info.get("duration", 0)),
                channel_name=info.get("uploader", ""),
            )

        except Exception as e:
            logger.error("오디오 다운로드 실패: %s — %s", youtube_url, str(e))
            raise RuntimeError(f"영상 다운로드 실패: {str(e)}") from e


class MockVideoDownloader(BaseVideoDownloader):
    """테스트용 가짜 다운로더"""

    async def download_audio(self, youtube_url: str) -> DownloadResult:
        """테스트용 가짜 결과를 반환합니다."""
        return DownloadResult(
            audio_path="/tmp/factis_downloads/test_audio.wav",
            video_title="[테스트] 가짜 뉴스 분석",
            video_duration=600.0,
            channel_name="테스트 채널",
        )
