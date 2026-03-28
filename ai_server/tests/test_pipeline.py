# @TASK P2-R4-T1 - 파이프라인 테스트
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# 각 서비스의 단위 테스트와 파이프라인 통합 테스트를 포함합니다.
# 모든 외부 API는 Mock으로 처리합니다.

from __future__ import annotations

import asyncio
import sys
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest

# ai_server 디렉토리를 모듈 검색 경로에 추가
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from models.schemas import (
    AnalysisResult,
    AnalysisStatus,
    Claim,
    ClaimExtractionResult,
    ClaimVerification,
    DownloadResult,
    NewsArticle,
    NewsMatchResult,
    TranscriptResult,
    TranscriptSegment,
    VerificationVerdict,
)
from services.pipeline import AnalysisPipeline, TaskStore
from services.video_downloader import MockVideoDownloader
from services.transcriber import MockTranscriber
from services.claim_extractor import MockClaimExtractor
from services.news_matcher import BigKindsNewsMatcher, MockNewsMatcher
from services.fact_checker import MockFactChecker, OpenAIFactChecker
from config.settings import Settings, reset_settings


# ==========================================
# 스키마 테스트
# ==========================================

class TestSchemas:
    """Pydantic 스키마 유효성 테스트"""

    def test_analysis_status_values(self):
        """분석 상태 값이 올바르게 정의되어 있는지 확인합니다."""
        assert AnalysisStatus.PENDING == "pending"
        assert AnalysisStatus.DOWNLOADING == "downloading"
        assert AnalysisStatus.TRANSCRIBING == "transcribing"
        assert AnalysisStatus.EXTRACTING == "extracting"
        assert AnalysisStatus.MATCHING == "matching"
        assert AnalysisStatus.VERIFYING == "verifying"
        assert AnalysisStatus.COMPLETED == "completed"
        assert AnalysisStatus.FAILED == "failed"

    def test_download_result_creation(self):
        """DownloadResult 생성이 올바르게 동작하는지 확인합니다."""
        result = DownloadResult(
            audio_path="/tmp/test.wav",
            video_title="테스트 영상",
            video_duration=300.0,
            channel_name="테스트 채널",
        )
        assert result.audio_path == "/tmp/test.wav"
        assert result.video_title == "테스트 영상"
        assert result.video_duration == 300.0

    def test_transcript_segment(self):
        """TranscriptSegment 생성이 올바르게 동작하는지 확인합니다."""
        segment = TranscriptSegment(start=0.0, end=5.0, text="안녕하세요")
        assert segment.start == 0.0
        assert segment.end == 5.0
        assert segment.text == "안녕하세요"

    def test_claim_has_uuid(self):
        """Claim 생성 시 고유 ID가 자동 부여되는지 확인합니다."""
        claim = Claim(text="GDP 성장률이 5%이다")
        assert claim.id is not None
        assert len(claim.id) > 0

    def test_verification_verdict_values(self):
        """VerificationVerdict 판정 값 확인합니다."""
        assert VerificationVerdict.TRUE == "true"
        assert VerificationVerdict.FALSE == "false"
        assert VerificationVerdict.UNVERIFIABLE == "unverifiable"

    def test_news_article_bigkinds_fields(self):
        """NewsArticle에 빅카인즈 확장 필드가 올바르게 설정되는지 확인합니다."""
        article = NewsArticle(
            news_id="BK-001",
            title="테스트 기사",
            content="테스트 본문",
            hilight="<em>테스트</em> 하이라이트",
            source="한국경제",
            published_at="2026-03-20T00:00:00.000+09:00",
            url="https://example.com/news/1",
            byline="홍길동",
            category=["경제>경제일반", "경제>증권_증시"],
            provider_news_id="HK-20260320-001",
            relevance_score=0.95,
        )
        assert article.news_id == "BK-001"
        assert article.hilight == "<em>테스트</em> 하이라이트"
        assert article.byline == "홍길동"
        assert len(article.category) == 2
        assert article.provider_news_id == "HK-20260320-001"

    def test_news_article_defaults(self):
        """NewsArticle 기본값이 올바르게 설정되는지 확인합니다."""
        article = NewsArticle(title="제목만 있는 기사")
        assert article.news_id == ""
        assert article.hilight == ""
        assert article.byline == ""
        assert article.category == []
        assert article.provider_news_id == ""

    def test_analysis_result_defaults(self):
        """AnalysisResult 기본값이 올바르게 설정되는지 확인합니다."""
        result = AnalysisResult()
        assert result.total_claims == 0
        assert result.overall_trust_score == 0.0
        assert result.verifications == []


# ==========================================
# 설정 테스트
# ==========================================

class TestSettings:
    """환경변수 설정 테스트"""

    def setup_method(self):
        """각 테스트 전에 설정을 초기화합니다."""
        reset_settings()

    def test_default_values(self):
        """기본값이 올바르게 설정되는지 확인합니다."""
        settings = Settings()
        assert settings.openai_api_key == ""
        assert settings.openai_model == "gpt-4o"
        assert settings.bigkinds_api_key == ""
        assert settings.whisper_model == "base"

    def test_bigkinds_settings_defaults(self):
        """빅카인즈 설정 기본값이 올바르게 설정되는지 확인합니다."""
        settings = Settings()
        assert settings.bigkinds_search_url == "https://tools.kinds.or.kr/search/news"
        assert settings.bigkinds_word_cloud_url == "https://tools.kinds.or.kr/word_cloud"
        assert settings.bigkinds_issue_ranking_url == "https://tools.kinds.or.kr/issue_ranking"
        assert settings.bigkinds_return_size == 5
        assert settings.bigkinds_hilight_length == 200
        assert settings.bigkinds_search_days == 365

    def test_env_prefix(self):
        """환경변수 접두사가 FACTCHECKR_인지 확인합니다."""
        assert Settings.model_config["env_prefix"] == "FACTCHECKR_"


# ==========================================
# TaskStore 테스트
# ==========================================

class TestTaskStore:
    """태스크 저장소 테스트"""

    def test_create_task(self, task_store: TaskStore):
        """태스크 생성이 올바르게 동작하는지 확인합니다."""
        task = task_store.create_task()
        assert task.task_id is not None
        assert task.status == AnalysisStatus.PENDING
        assert task.progress == 0.0

    def test_get_task(self, task_store: TaskStore):
        """생성된 태스크를 조회할 수 있는지 확인합니다."""
        task = task_store.create_task()
        retrieved = task_store.get_task(task.task_id)
        assert retrieved is not None
        assert retrieved.task_id == task.task_id

    def test_get_nonexistent_task(self, task_store: TaskStore):
        """존재하지 않는 태스크 조회 시 None을 반환하는지 확인합니다."""
        result = task_store.get_task("nonexistent-id")
        assert result is None

    def test_update_task_status(self, task_store: TaskStore):
        """태스크 상태 업데이트가 올바르게 동작하는지 확인합니다."""
        task = task_store.create_task()
        updated = task_store.update_task(
            task.task_id,
            status=AnalysisStatus.DOWNLOADING,
            current_step="다운로드 중",
            progress=0.1,
        )
        assert updated is not None
        assert updated.status == AnalysisStatus.DOWNLOADING
        assert updated.progress == 0.1
        assert updated.current_step == "다운로드 중"

    def test_update_task_with_error(self, task_store: TaskStore):
        """에러 상태 업데이트가 올바르게 동작하는지 확인합니다."""
        task = task_store.create_task()
        updated = task_store.update_task(
            task.task_id,
            status=AnalysisStatus.FAILED,
            error="다운로드 실패",
        )
        assert updated is not None
        assert updated.status == AnalysisStatus.FAILED
        assert updated.error == "다운로드 실패"

    def test_list_tasks(self, task_store: TaskStore):
        """모든 태스크 목록 조회가 올바르게 동작하는지 확인합니다."""
        task_store.create_task()
        task_store.create_task()
        tasks = task_store.list_tasks()
        assert len(tasks) == 2


# ==========================================
# Mock 서비스 테스트
# ==========================================

class TestMockVideoDownloader:
    """Mock 비디오 다운로더 테스트"""

    @pytest.mark.asyncio
    async def test_download_returns_result(self):
        """Mock 다운로더가 DownloadResult를 반환하는지 확인합니다."""
        downloader = MockVideoDownloader()
        result = await downloader.download_audio("https://youtube.com/watch?v=test")
        assert isinstance(result, DownloadResult)
        assert result.audio_path != ""
        assert result.video_title != ""
        assert result.video_duration > 0


class TestMockTranscriber:
    """Mock 음성 인식기 테스트"""

    @pytest.mark.asyncio
    async def test_transcribe_returns_result(self):
        """Mock 음성 인식기가 TranscriptResult를 반환하는지 확인합니다."""
        transcriber = MockTranscriber()
        result = await transcriber.transcribe("/tmp/test.wav")
        assert isinstance(result, TranscriptResult)
        assert len(result.text) > 0
        assert len(result.segments) > 0
        assert result.language == "ko"


class TestMockClaimExtractor:
    """Mock 주장 추출기 테스트"""

    @pytest.mark.asyncio
    async def test_extract_returns_claims(self):
        """Mock 주장 추출기가 ClaimExtractionResult를 반환하는지 확인합니다."""
        extractor = MockClaimExtractor()
        transcript = TranscriptResult(text="테스트 텍스트", segments=[], language="ko")
        result = await extractor.extract_claims(transcript)
        assert isinstance(result, ClaimExtractionResult)
        assert result.total_count > 0
        assert len(result.claims) > 0
        assert result.claims[0].text != ""


class TestMockNewsMatcher:
    """Mock 뉴스 매칭 테스트"""

    @pytest.mark.asyncio
    async def test_match_returns_results(self):
        """Mock 뉴스 매칭이 NewsMatchResult를 반환하는지 확인합니다."""
        matcher = MockNewsMatcher()
        claims = ClaimExtractionResult(
            claims=[Claim(text="테스트 주장")],
            total_count=1,
        )
        results = await matcher.match_news(claims)
        assert len(results) == 1
        assert isinstance(results[0], NewsMatchResult)
        assert results[0].match_count > 0
        assert len(results[0].articles) > 0

    @pytest.mark.asyncio
    async def test_mock_articles_have_bigkinds_fields(self):
        """Mock 뉴스 기사에 빅카인즈 확장 필드가 포함되는지 확인합니다."""
        matcher = MockNewsMatcher()
        claims = ClaimExtractionResult(
            claims=[Claim(text="테스트 주장")],
            total_count=1,
        )
        results = await matcher.match_news(claims)
        article = results[0].articles[0]
        # 빅카인즈 확장 필드 확인
        assert article.news_id != ""
        assert article.hilight != ""
        assert article.byline != ""
        assert len(article.category) > 0
        assert article.provider_news_id != ""


class TestMockFactChecker:
    """Mock 팩트체커 테스트"""

    @pytest.mark.asyncio
    async def test_verify_returns_result(self):
        """Mock 팩트체커가 AnalysisResult를 반환하는지 확인합니다."""
        checker = MockFactChecker()
        extraction = ClaimExtractionResult(
            claims=[Claim(text="테스트 주장")],
            total_count=1,
        )
        news_matches = [
            NewsMatchResult(claim_id=extraction.claims[0].id, articles=[], match_count=0)
        ]
        download = DownloadResult(
            audio_path="/tmp/test.wav",
            video_title="테스트",
            video_duration=300.0,
            channel_name="테스트 채널",
        )
        result = await checker.verify(extraction, news_matches, download)
        assert isinstance(result, AnalysisResult)
        assert result.total_claims > 0
        assert result.overall_trust_score >= 0


# ==========================================
# 신뢰도 점수 계산 테스트
# ==========================================

class TestTrustScoreCalculation:
    """신뢰도 점수 계산 로직 테스트"""

    def test_all_true_claims(self):
        """모든 주장이 사실인 경우 높은 점수를 반환합니다."""
        verifications = [
            ClaimVerification(
                claim_id="1", claim_text="주장1",
                verdict=VerificationVerdict.TRUE, confidence=1.0,
            ),
            ClaimVerification(
                claim_id="2", claim_text="주장2",
                verdict=VerificationVerdict.TRUE, confidence=1.0,
            ),
        ]
        score = OpenAIFactChecker._calculate_trust_score(verifications)
        assert score == 100.0

    def test_all_false_claims(self):
        """모든 주장이 거짓인 경우 낮은 점수를 반환합니다."""
        verifications = [
            ClaimVerification(
                claim_id="1", claim_text="주장1",
                verdict=VerificationVerdict.FALSE, confidence=1.0,
            ),
        ]
        score = OpenAIFactChecker._calculate_trust_score(verifications)
        assert score == 0.0

    def test_mixed_claims(self):
        """혼합된 판정의 경우 중간 점수를 반환합니다."""
        verifications = [
            ClaimVerification(
                claim_id="1", claim_text="주장1",
                verdict=VerificationVerdict.TRUE, confidence=1.0,
            ),
            ClaimVerification(
                claim_id="2", claim_text="주장2",
                verdict=VerificationVerdict.FALSE, confidence=1.0,
            ),
        ]
        score = OpenAIFactChecker._calculate_trust_score(verifications)
        assert score == 50.0

    def test_empty_verifications(self):
        """검증 결과가 없는 경우 0점을 반환합니다."""
        score = OpenAIFactChecker._calculate_trust_score([])
        assert score == 0.0

    def test_zero_confidence(self):
        """신뢰도가 모두 0인 경우 기본 50점을 반환합니다."""
        verifications = [
            ClaimVerification(
                claim_id="1", claim_text="주장1",
                verdict=VerificationVerdict.TRUE, confidence=0.0,
            ),
        ]
        score = OpenAIFactChecker._calculate_trust_score(verifications)
        assert score == 50.0


# ==========================================
# 요약 생성 테스트
# ==========================================

class TestSummaryGeneration:
    """요약 텍스트 생성 테스트"""

    def test_generate_summary_with_verifications(self):
        """검증 결과가 있는 경우 요약을 생성합니다."""
        verifications = [
            ClaimVerification(
                claim_id="1", claim_text="주장1",
                verdict=VerificationVerdict.TRUE, confidence=1.0,
            ),
            ClaimVerification(
                claim_id="2", claim_text="주장2",
                verdict=VerificationVerdict.FALSE, confidence=1.0,
            ),
        ]
        summary = OpenAIFactChecker._generate_summary(verifications, 50.0)
        assert "2개 주장" in summary
        assert "50.0" in summary

    def test_generate_summary_empty(self):
        """검증 결과가 없는 경우 기본 메시지를 반환합니다."""
        summary = OpenAIFactChecker._generate_summary([], 0.0)
        assert "검증할 주장이 없습니다" in summary


# ==========================================
# 빅카인즈 쿼리 빌더 테스트
# ==========================================

class TestBigKindsQueryBuilder:
    """BigKindsNewsMatcher의 쿼리 빌더 테스트"""

    def test_build_query_with_enough_keywords(self):
        """키워드가 3개 이상이면 상위 3개를 AND로 결합합니다."""
        claim = Claim(text="한국 경제 성장률이 올해 3.5%를 기록했다고 발표했다")
        query = BigKindsNewsMatcher._build_search_query(claim)
        # AND 연산자로 결합된 쿼리인지 확인
        assert "AND" in query
        # 최대 3개 키워드로 제한 (AND 2개 = 키워드 3개)
        assert query.count("AND") <= 2

    def test_build_query_with_few_keywords(self):
        """키워드가 적으면 있는 것만 AND로 결합합니다."""
        claim = Claim(text="경제 성장")
        query = BigKindsNewsMatcher._build_search_query(claim)
        # 키워드가 있으면 AND로 결합
        assert "경제" in query
        assert "성장" in query

    def test_build_query_fallback_to_phrase(self):
        """키워드 추출 실패 시 원문 구문 검색을 사용합니다."""
        # 불용어로만 구성된 텍스트 (키워드 추출 불가)
        claim = Claim(text="이 그 저 것 등 및")
        query = BigKindsNewsMatcher._build_search_query(claim)
        # 구문 검색 (큰따옴표)으로 폴백
        assert query.startswith('"')
        assert query.endswith('"')

    def test_extract_keywords_removes_stopwords(self):
        """불용어를 제거하고 핵심 키워드만 추출합니다."""
        keywords = BigKindsNewsMatcher._extract_keywords(
            "정부에서 발표한 경제 성장률에 대한 보고서를 통해 확인했다"
        )
        # 불용어 ('에서', '대한', '통해') 제거 확인
        assert "에서" not in keywords
        assert "대한" not in keywords
        assert "통해" not in keywords
        # 핵심 키워드 포함 확인
        assert "정부" in keywords
        assert "경제" in keywords
        assert "성장률" in keywords

    def test_extract_keywords_includes_numbers(self):
        """숫자+단위 패턴도 키워드로 포함합니다."""
        keywords = BigKindsNewsMatcher._extract_keywords(
            "GDP 성장률이 3.5%를 기록하며 100조원 규모의 투자가 진행됐다"
        )
        # 숫자+단위 패턴 확인
        assert "3.5%" in keywords
        assert "100조원" in keywords or "100조" in keywords

    def test_extract_keywords_no_duplicates(self):
        """중복 키워드를 제거합니다."""
        keywords = BigKindsNewsMatcher._extract_keywords(
            "경제 성장과 경제 발전은 다르다"
        )
        # 중복 제거 확인
        assert keywords.count("경제") == 1


class TestBigKindsResponseParsing:
    """BigKindsNewsMatcher의 응답 파싱 테스트"""

    def test_parse_document_full_fields(self):
        """모든 필드가 있는 빅카인즈 응답 문서를 올바르게 파싱합니다."""
        doc = {
            "news_id": "NEWS-001",
            "title": "GDP 성장률 3.5%",
            "content": "본문 내용" * 100,  # 긴 본문
            "hilight": "<em>GDP</em> 성장률 3.5%",
            "provider": "한국경제",
            "published_at": "2026-03-20T00:00:00.000+09:00",
            "provider_link_page": "https://example.com/news/1",
            "byline": "홍길동",
            "category": ["경제>경제일반"],
            "provider_news_id": "HK-20260320-001",
            "score": 0.95,
        }
        article = BigKindsNewsMatcher._parse_document(doc)
        assert article.news_id == "NEWS-001"
        assert article.title == "GDP 성장률 3.5%"
        assert len(article.content) <= 500  # 본문 500자 제한
        assert article.hilight == "<em>GDP</em> 성장률 3.5%"
        assert article.source == "한국경제"
        assert article.byline == "홍길동"
        assert article.category == ["경제>경제일반"]
        assert article.provider_news_id == "HK-20260320-001"
        assert article.relevance_score == 0.95

    def test_parse_document_missing_fields(self):
        """누락된 필드가 있는 빅카인즈 응답 문서도 안전하게 파싱합니다."""
        doc = {"title": "제목만 있는 기사"}
        article = BigKindsNewsMatcher._parse_document(doc)
        assert article.title == "제목만 있는 기사"
        assert article.news_id == ""
        assert article.hilight == ""
        assert article.byline == ""
        assert article.category == []
        assert article.provider_news_id == ""
        assert article.relevance_score == 0.0

    def test_parse_document_null_category(self):
        """category가 None인 경우 빈 리스트로 처리합니다."""
        doc = {"title": "기사", "category": None}
        article = BigKindsNewsMatcher._parse_document(doc)
        assert article.category == []


class TestBigKindsErrorHandling:
    """BigKindsNewsMatcher의 에러 처리 테스트"""

    @pytest.mark.asyncio
    async def test_api_error_code_raises_runtime_error(self):
        """빅카인즈 API가 에러 코드를 반환하면 RuntimeError가 발생합니다."""
        import httpx
        from unittest.mock import MagicMock

        matcher = BigKindsNewsMatcher()
        settings = Settings(
            bigkinds_api_key="test-key",
            bigkinds_search_url="https://tools.kinds.or.kr/search/news",
        )

        # 에러 응답 mock
        mock_response = MagicMock()
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "result": -1,
            "reason": "Invalid access key",
        }

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_response

        claim = Claim(text="테스트 주장", category="정치")

        with pytest.raises(RuntimeError, match="빅카인즈 API 에러"):
            await matcher._search_for_claim(mock_client, claim, settings)

    @pytest.mark.asyncio
    async def test_api_success_code_returns_results(self):
        """빅카인즈 API가 result=0을 반환하면 정상 처리합니다."""
        from unittest.mock import MagicMock

        matcher = BigKindsNewsMatcher()
        settings = Settings(
            bigkinds_api_key="test-key",
            bigkinds_search_url="https://tools.kinds.or.kr/search/news",
        )

        # 성공 응답 mock (result: 0)
        mock_response = MagicMock()
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "result": 0,
            "return_object": {
                "total_hits": 1,
                "documents": [{
                    "news_id": "NEWS-001",
                    "title": "테스트 기사",
                    "content": "테스트 본문",
                    "hilight": "<em>테스트</em>",
                    "provider": "한국경제",
                    "published_at": "2026-03-20",
                    "provider_link_page": "https://example.com/1",
                    "byline": "홍길동",
                    "category": ["경제>경제일반"],
                    "provider_news_id": "HK-001",
                    "score": 0.9,
                }],
            },
        }

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_response

        claim = Claim(text="경제 성장률 테스트", category="경제")
        result = await matcher._search_for_claim(mock_client, claim, settings)

        assert result.match_count == 1
        assert result.articles[0].news_id == "NEWS-001"
        assert result.articles[0].byline == "홍길동"
        assert result.articles[0].category == ["경제>경제일반"]

    @pytest.mark.asyncio
    async def test_individual_claim_failure_returns_empty(self):
        """개별 주장 검색 실패 시 빈 결과로 처리합니다."""
        from unittest.mock import MagicMock

        matcher = BigKindsNewsMatcher()

        # API 키 설정
        settings = Settings(
            bigkinds_api_key="test-key",
            bigkinds_search_url="https://tools.kinds.or.kr/search/news",
        )

        claims = ClaimExtractionResult(
            claims=[Claim(text="테스트 주장")],
            total_count=1,
        )

        # _search_for_claim이 예외를 던지도록 패치
        with patch.object(
            BigKindsNewsMatcher,
            "_search_for_claim",
            side_effect=RuntimeError("API 호출 실패"),
        ), patch("services.news_matcher.get_settings", return_value=settings):
            results = await matcher.match_news(claims)

        assert len(results) == 1
        assert results[0].match_count == 0
        assert results[0].articles == []


class TestBigKindsCategoryMapping:
    """빅카인즈 카테고리 매핑 테스트"""

    @pytest.mark.asyncio
    async def test_category_mapping_applied(self):
        """주장의 category가 빅카인즈 카테고리로 매핑되어 API 요청에 포함됩니다."""
        from unittest.mock import MagicMock

        matcher = BigKindsNewsMatcher()
        settings = Settings(
            bigkinds_api_key="test-key",
            bigkinds_search_url="https://tools.kinds.or.kr/search/news",
        )

        # 성공 응답 mock
        mock_response = MagicMock()
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "result": 0,
            "return_object": {"total_hits": 0, "documents": []},
        }

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_response

        # 카테고리가 "정치"인 주장
        claim = Claim(text="대통령 탄핵 관련 주장", category="정치")
        await matcher._search_for_claim(mock_client, claim, settings)

        # API 요청 본문에 카테고리가 포함되었는지 확인
        call_args = mock_client.post.call_args
        request_body = call_args.kwargs.get("json") or call_args[1].get("json")
        assert "category" in request_body["argument"]
        assert "정치>정치일반" in request_body["argument"]["category"]

    @pytest.mark.asyncio
    async def test_no_category_mapping_when_unknown(self):
        """알 수 없는 카테고리일 때는 category 필터를 포함하지 않습니다."""
        from unittest.mock import MagicMock

        matcher = BigKindsNewsMatcher()
        settings = Settings(
            bigkinds_api_key="test-key",
            bigkinds_search_url="https://tools.kinds.or.kr/search/news",
        )

        mock_response = MagicMock()
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "result": 0,
            "return_object": {"total_hits": 0, "documents": []},
        }

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_response

        # 매핑되지 않는 카테고리
        claim = Claim(text="테스트 주장", category="기타")
        await matcher._search_for_claim(mock_client, claim, settings)

        call_args = mock_client.post.call_args
        request_body = call_args.kwargs.get("json") or call_args[1].get("json")
        assert "category" not in request_body["argument"]


# ==========================================
# 파이프라인 통합 테스트
# ==========================================

class TestPipeline:
    """파이프라인 오케스트레이터 통합 테스트"""

    @pytest.mark.asyncio
    async def test_pipeline_full_run(self, task_store: TaskStore, mock_pipeline: AnalysisPipeline):
        """파이프라인 전체 실행이 성공적으로 완료되는지 확인합니다."""
        task = task_store.create_task()
        await mock_pipeline.run(task.task_id, "https://youtube.com/watch?v=test")

        # 완료 상태 확인
        result = task_store.get_task(task.task_id)
        assert result is not None
        assert result.status == AnalysisStatus.COMPLETED
        assert result.progress == 1.0
        assert result.result is not None
        assert result.result.total_claims > 0

    @pytest.mark.asyncio
    async def test_pipeline_failure_handling(self, task_store: TaskStore):
        """파이프라인 실패 시 에러 상태로 전환되는지 확인합니다."""
        # 다운로드에서 실패하는 Mock 생성
        failing_downloader = MockVideoDownloader()
        failing_downloader.download_audio = AsyncMock(
            side_effect=RuntimeError("다운로드 실패")
        )

        pipeline = AnalysisPipeline(
            task_store=task_store,
            downloader=failing_downloader,
        )

        task = task_store.create_task()
        await pipeline.run(task.task_id, "https://youtube.com/watch?v=test")

        # 실패 상태 확인
        result = task_store.get_task(task.task_id)
        assert result is not None
        assert result.status == AnalysisStatus.FAILED
        assert result.error is not None
        assert "다운로드 실패" in result.error

    @pytest.mark.asyncio
    async def test_pipeline_steps_progression(self, task_store: TaskStore):
        """파이프라인이 각 단계를 순차적으로 거치는지 확인합니다."""
        # 각 단계에서 상태를 기록하는 커스텀 파이프라인
        recorded_statuses: list[AnalysisStatus] = []
        original_update = task_store.update_task

        def tracking_update(task_id, **kwargs):
            if "status" in kwargs and kwargs["status"] is not None:
                recorded_statuses.append(kwargs["status"])
            return original_update(task_id, **kwargs)

        task_store.update_task = tracking_update

        pipeline = AnalysisPipeline(task_store=task_store)
        task = task_store.create_task()
        await pipeline.run(task.task_id, "https://youtube.com/watch?v=test")

        # 모든 단계를 순서대로 거쳤는지 확인
        expected = [
            AnalysisStatus.DOWNLOADING,
            AnalysisStatus.TRANSCRIBING,
            AnalysisStatus.EXTRACTING,
            AnalysisStatus.MATCHING,
            AnalysisStatus.VERIFYING,
            AnalysisStatus.COMPLETED,
        ]
        assert recorded_statuses == expected


# ==========================================
# API 엔드포인트 테스트
# ==========================================

class TestAnalyzeEndpoint:
    """POST /api/analyze 엔드포인트 테스트"""

    @pytest.mark.asyncio
    async def test_analyze_valid_url(self, async_client):
        """유효한 유튜브 URL로 분석 요청 시 태스크 ID를 반환합니다."""
        response = await async_client.post(
            "/api/analyze",
            json={"youtube_url": "https://youtube.com/watch?v=test123"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "task_id" in data
        assert data["status"] == "pending"
        assert data["message"] == "분석이 시작되었습니다."

    @pytest.mark.asyncio
    async def test_analyze_empty_url(self, async_client):
        """빈 URL로 요청 시 400 에러를 반환합니다."""
        response = await async_client.post(
            "/api/analyze",
            json={"youtube_url": ""},
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_analyze_invalid_url(self, async_client):
        """유효하지 않은 URL로 요청 시 400 에러를 반환합니다."""
        response = await async_client.post(
            "/api/analyze",
            json={"youtube_url": "https://example.com/not-youtube"},
        )
        assert response.status_code == 400


class TestStatusEndpoint:
    """GET /api/analyze/{task_id}/status 엔드포인트 테스트"""

    @pytest.mark.asyncio
    async def test_status_after_request(self, async_client):
        """분석 요청 후 상태 조회가 동작하는지 확인합니다."""
        # 먼저 분석 요청
        response = await async_client.post(
            "/api/analyze",
            json={"youtube_url": "https://youtube.com/watch?v=test123"},
        )
        task_id = response.json()["task_id"]

        # 비동기 태스크가 완료될 시간을 줌
        await asyncio.sleep(0.5)

        # 상태 조회
        status_response = await async_client.get(f"/api/analyze/{task_id}/status")
        assert status_response.status_code == 200
        data = status_response.json()
        assert data["task_id"] == task_id
        # 완료 또는 진행 중 상태
        assert data["status"] in [s.value for s in AnalysisStatus]

    @pytest.mark.asyncio
    async def test_status_not_found(self, async_client):
        """존재하지 않는 태스크 ID로 조회 시 404를 반환합니다."""
        response = await async_client.get("/api/analyze/nonexistent-id/status")
        assert response.status_code == 404


class TestHealthEndpoint:
    """GET /health 엔드포인트 테스트"""

    @pytest.mark.asyncio
    async def test_health_check(self, async_client):
        """헬스체크가 올바르게 응답하는지 확인합니다."""
        response = await async_client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert data["service"] == "factcheckr-ai"
