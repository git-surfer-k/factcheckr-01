# @TASK P2-R4-T1 - 빅카인즈 뉴스 매칭 서비스
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# 빅카인즈 뉴스 API를 사용하여 추출된 주장과 관련된 뉴스를 검색합니다.
# 각 주장에 대해 관련 뉴스 기사를 매칭하여 팩트체크 근거로 사용합니다.
#
# 빅카인즈 API 스펙 기반 보강:
# - 키워드 기반 쿼리 빌더 (AND/OR 연산자)
# - 카테고리 매핑 (주장 분류 -> 빅카인즈 분류체계)
# - result 코드 기반 에러 처리
# - 동적 날짜 범위 (settings.bigkinds_search_days 기반)
# - 정확도순 정렬 (_score desc)
# - fields 파라미터로 필요한 필드만 요청
# - 뉴스 상세 조회 (search_by_ids)

from __future__ import annotations

import logging
import re
from abc import ABC, abstractmethod
from datetime import datetime, timedelta

from models.schemas import (
    Claim,
    ClaimExtractionResult,
    NewsArticle,
    NewsMatchResult,
)
from config.settings import Settings, get_settings

logger = logging.getLogger(__name__)

# 빅카인즈 뉴스 통합 분류체계 매핑
# 주장의 category 값을 빅카인즈 API의 category 코드로 변환합니다.
CATEGORY_MAP: dict[str, str] = {
    "정치": "정치>정치일반",
    "경제": "경제>경제일반",
    "사회": "사회>사회일반",
    "국제": "국제>국제일반",
    "문화": "문화",
    "스포츠": "스포츠",
    "IT": "IT_과학",
    "과학": "IT_과학",
}

# 한국어 불용어 목록 (검색 키워드 추출 시 제거)
_STOPWORDS: set[str] = {
    "이", "그", "저", "것", "수", "등", "및", "또", "더", "매우",
    "약", "위해", "대한", "통해", "따르면", "있다", "없다", "했다",
    "한다", "된다", "이다", "라고", "에서", "으로", "에게", "부터",
    "까지", "처럼", "만큼", "때문", "하는", "하고", "하며", "하면",
    "했으며", "됐다", "됐으며", "라며", "라면서", "에는", "에도",
    "에서는", "으로는", "이라고", "라는", "하지만", "그러나", "그리고",
    "또한", "한편", "반면", "오히려", "때문에", "의해", "관련",
}

# 빅카인즈 API에 요청할 기본 반환 필드 목록
_DEFAULT_FIELDS: list[str] = [
    "byline",
    "category",
    "category_incident",
    "provider_news_id",
]


class BaseNewsMatcher(ABC):
    """뉴스 매칭 인터페이스"""

    @abstractmethod
    async def match_news(self, extraction_result: ClaimExtractionResult) -> list[NewsMatchResult]:
        """추출된 주장에 관련 뉴스를 매칭합니다."""
        ...


class BigKindsNewsMatcher(BaseNewsMatcher):
    """빅카인즈 API를 사용한 뉴스 매칭"""

    async def match_news(self, extraction_result: ClaimExtractionResult) -> list[NewsMatchResult]:
        """
        각 주장에 대해 빅카인즈 뉴스 API로 관련 기사를 검색합니다.

        Args:
            extraction_result: 주장 추출 결과

        Returns:
            list[NewsMatchResult]: 주장별 관련 뉴스 목록

        Raises:
            RuntimeError: API 키가 설정되지 않은 경우
        """
        import httpx

        settings = get_settings()

        if not settings.bigkinds_api_key:
            raise RuntimeError("BIGKINDS_API_KEY가 설정되지 않았습니다.")

        results: list[NewsMatchResult] = []

        async with httpx.AsyncClient(timeout=30.0) as client:
            for claim in extraction_result.claims:
                try:
                    match_result = await self._search_for_claim(client, claim, settings)
                    results.append(match_result)
                except Exception as e:
                    logger.warning("주장 '%s' 뉴스 검색 실패: %s", claim.text[:30], str(e))
                    # 개별 실패는 빈 결과로 처리
                    results.append(NewsMatchResult(
                        claim_id=claim.id,
                        articles=[],
                        match_count=0,
                    ))

        logger.info("뉴스 매칭 완료: %d개 주장 처리", len(results))
        return results

    async def search_by_ids(self, news_ids: list[str]) -> list[NewsArticle]:
        """
        뉴스 ID 목록으로 상세 기사를 조회합니다.

        검증 단계에서 뉴스 전문이 필요할 때 사용합니다.

        Args:
            news_ids: 빅카인즈 뉴스 고유 ID 목록

        Returns:
            list[NewsArticle]: 조회된 뉴스 기사 목록

        Raises:
            RuntimeError: API 키 미설정 또는 API 에러 응답 시
        """
        import httpx

        settings = get_settings()

        if not settings.bigkinds_api_key:
            raise RuntimeError("BIGKINDS_API_KEY가 설정되지 않았습니다.")

        request_body = {
            "access_key": settings.bigkinds_api_key,
            "argument": {
                "news_ids": news_ids,
                "fields": ["byline", "category", "category_incident", "provider_news_id"],
            },
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                settings.bigkinds_search_url,
                json=request_body,
            )
            response.raise_for_status()
            data = response.json()

        # 빅카인즈 API 에러 코드 체크
        result_code = data.get("result", -1)
        if result_code != 0:
            error_msg = data.get("reason", "알 수 없는 에러")
            raise RuntimeError(f"빅카인즈 API 에러 (코드: {result_code}): {error_msg}")

        documents = data.get("return_object", {}).get("documents", [])
        return [self._parse_document(doc) for doc in documents]

    async def _search_for_claim(
        self,
        client: "httpx.AsyncClient",
        claim: Claim,
        settings: Settings,
    ) -> NewsMatchResult:
        """개별 주장에 대해 뉴스를 검색합니다."""
        # 동적 날짜 범위 계산
        until_date = datetime.now()
        from_date = until_date - timedelta(days=settings.bigkinds_search_days)

        # 주장에서 검색 쿼리 생성
        query = self._build_search_query(claim)

        # 카테고리 매핑 (주장의 category가 매핑 가능한 경우)
        categories = []
        if claim.category and claim.category in CATEGORY_MAP:
            categories.append(CATEGORY_MAP[claim.category])

        # 빅카인즈 API 요청 구성
        argument: dict = {
            "query": query,
            "published_at": {
                "from": from_date.strftime("%Y-%m-%d"),
                "until": until_date.strftime("%Y-%m-%d"),
            },
            "sort": {"_score": "desc"},  # 관련도순 정렬
            "hilight": settings.bigkinds_hilight_length,
            "return_from": 0,
            "return_size": settings.bigkinds_return_size,
            "fields": _DEFAULT_FIELDS,
        }

        # 카테고리 필터가 있으면 추가
        if categories:
            argument["category"] = categories

        request_body = {
            "access_key": settings.bigkinds_api_key,
            "argument": argument,
        }

        response = await client.post(
            settings.bigkinds_search_url,
            json=request_body,
        )
        response.raise_for_status()
        data = response.json()

        # 빅카인즈 API 에러 코드 체크 (result != 0이면 에러)
        result_code = data.get("result", -1)
        if result_code != 0:
            error_msg = data.get("reason", "알 수 없는 에러")
            raise RuntimeError(f"빅카인즈 API 에러 (코드: {result_code}): {error_msg}")

        # 응답 파싱 (모든 필드 포함)
        documents = data.get("return_object", {}).get("documents", [])
        articles = [self._parse_document(doc) for doc in documents]

        return NewsMatchResult(
            claim_id=claim.id,
            articles=articles,
            match_count=len(articles),
        )

    @staticmethod
    def _build_search_query(claim: Claim) -> str:
        """
        주장에서 검색 키워드를 추출하고 AND 연산자로 결합합니다.

        빅카인즈 API는 AND, OR, NOT, ""(구문검색), () 연산자를 지원합니다.
        주장 텍스트에서 핵심 키워드만 추출하여 검색 품질을 높입니다.

        Args:
            claim: 검색할 주장

        Returns:
            str: 빅카인즈 검색 쿼리 문자열
        """
        keywords = BigKindsNewsMatcher._extract_keywords(claim.text)
        if len(keywords) >= 3:
            # 키워드가 충분하면 상위 3개를 AND로 결합
            return " AND ".join(keywords[:3])
        elif keywords:
            return " AND ".join(keywords)
        else:
            # 키워드 추출 실패 시 원문 앞 50자를 구문 검색
            return f'"{claim.text[:50]}"'

    @staticmethod
    def _extract_keywords(text: str) -> list[str]:
        """
        텍스트에서 핵심 키워드를 추출합니다.

        불용어를 제거하고, 2글자 이상인 단어만 반환합니다.
        숫자+단위 조합(예: 3.5%, 100만)도 키워드로 포함합니다.
        한국어 조사(은/는/이/가/을/를/에/에서/으로 등)를 분리하여 처리합니다.

        Args:
            text: 키워드를 추출할 텍스트

        Returns:
            list[str]: 추출된 키워드 목록 (중요도순)
        """
        # 숫자+단위 패턴을 먼저 추출 (예: 3.5%, 100만명, 10조원)
        number_patterns = re.findall(r'\d+[\.\,]?\d*[%조억만천원달러명개건호]?', text)

        # 한국어/영어 단어 추출
        words = re.findall(r'[가-힣]{2,}|[a-zA-Z]{2,}', text)

        # 한국어 조사 패턴을 제거하여 어근 추출
        # 예: "정부에서" -> "정부", "성장률에" -> "성장률", "보고서를" -> "보고서"
        _PARTICLE_PATTERN = re.compile(
            r'(에서는|에서|에게서|으로는|으로|에는|에게|에도|부터|까지|처럼|만큼'
            r'|이라고|라고|라는|라며|라면서|이라는'
            r'|에|은|는|이|가|을|를|와|과|의|도|로|서)$'
        )
        stripped_words = []
        for w in words:
            stem = _PARTICLE_PATTERN.sub('', w)
            # 조사 제거 후 1글자만 남으면 원래 단어 사용 (예: "그가" -> "그" 방지 불필요)
            if len(stem) >= 2:
                stripped_words.append(stem)
            elif len(w) >= 2:
                stripped_words.append(w)

        # 불용어 제거
        filtered = [w for w in stripped_words if w not in _STOPWORDS]

        # 숫자 패턴 + 필터링된 단어를 결합 (숫자가 팩트체크에 중요하므로 우선)
        result: list[str] = []
        seen: set[str] = set()
        for kw in number_patterns + filtered:
            if kw not in seen:
                seen.add(kw)
                result.append(kw)

        return result

    @staticmethod
    def _parse_document(doc: dict) -> NewsArticle:
        """
        빅카인즈 API 응답의 document 객체를 NewsArticle로 변환합니다.

        Args:
            doc: 빅카인즈 API 응답의 개별 문서 딕셔너리

        Returns:
            NewsArticle: 변환된 뉴스 기사 객체
        """
        return NewsArticle(
            news_id=doc.get("news_id", ""),
            title=doc.get("title", ""),
            content=doc.get("content", "")[:500],
            hilight=doc.get("hilight", ""),
            source=doc.get("provider", ""),
            published_at=doc.get("published_at", ""),
            url=doc.get("provider_link_page", ""),
            byline=doc.get("byline", ""),
            category=doc.get("category", []) or [],
            provider_news_id=doc.get("provider_news_id", ""),
            relevance_score=float(doc.get("score", 0.0)),
        )


class MockNewsMatcher(BaseNewsMatcher):
    """테스트용 가짜 뉴스 매칭"""

    async def match_news(self, extraction_result: ClaimExtractionResult) -> list[NewsMatchResult]:
        """테스트용 가짜 뉴스 매칭 결과를 반환합니다."""
        results = []
        for claim in extraction_result.claims:
            results.append(NewsMatchResult(
                claim_id=claim.id,
                articles=[
                    NewsArticle(
                        news_id="NEWS-001",
                        title="GDP 성장률 3.5% 기록",
                        content="한국은행 발표에 따르면 올해 GDP 성장률은 3.5%로 집계되었다.",
                        hilight="GDP <em>성장률</em>은 <em>3.5%</em>로 집계",
                        source="한국경제",
                        published_at="2026-03-20",
                        url="https://example.com/news/1",
                        byline="홍길동",
                        category=["경제>경제일반"],
                        provider_news_id="HK-20260320-001",
                        relevance_score=0.85,
                    ),
                    NewsArticle(
                        news_id="NEWS-002",
                        title="경제성장률 전망 하향 조정",
                        content="IMF가 한국 경제성장률 전망을 4%에서 3.2%로 하향 조정했다.",
                        hilight="<em>경제성장률</em> 전망을 <em>하향</em> 조정",
                        source="연합뉴스",
                        published_at="2026-03-18",
                        url="https://example.com/news/2",
                        byline="김철수",
                        category=["경제>경제일반"],
                        provider_news_id="YH-20260318-002",
                        relevance_score=0.72,
                    ),
                ],
                match_count=2,
            ))
        return results
