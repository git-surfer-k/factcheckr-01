# @TASK P2-R4-T1 - 환경변수 설정
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# pydantic-settings를 사용하여 환경변수를 관리합니다.
# OPENAI_API_KEY, BIGKINDS_API_KEY 등 외부 서비스 키를 환경변수에서 읽어옵니다.

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """AI 서버 환경변수 설정"""

    # OpenAI API 설정
    openai_api_key: str = ""
    openai_model: str = "gpt-4o"

    # 빅카인즈 뉴스 API 설정
    bigkinds_api_key: str = ""
    bigkinds_base_url: str = "https://tools.kinds.or.kr/search/news"

    # Whisper 설정
    whisper_model: str = "base"

    # 다운로드 경로
    download_dir: str = "/tmp/factis_downloads"

    # Rails 서버 연동
    rails_api_url: str = "http://localhost:3000"
    internal_api_key: str = ""

    # 앱 설정
    debug: bool = False

    model_config = {
        "env_prefix": "FACTIS_",
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }


# 싱글톤 설정 인스턴스
_settings: Settings | None = None


def get_settings() -> Settings:
    """설정 싱글톤을 반환합니다."""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings


def reset_settings() -> None:
    """테스트 시 설정을 초기화합니다."""
    global _settings
    _settings = None
