# @TASK P2-R4-T1 - 빅카인즈 뉴스 매칭 서비스
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# 빅카인즈 뉴스 API를 사용하여 추출된 주장과 관련된 뉴스를 검색합니다.
# 각 주장에 대해 관련 뉴스 기사를 매칭하여 팩트체크 근거로 사용합니다.

from __future__ import annotations

import logging
from abc import ABC, abstractmethod

from models.schemas import (
    Claim,
    ClaimExtractionResult,
    NewsArticle,
    NewsMatchResult,
)
from config.settings import get_settings

logger = logging.getLogger(__name__)


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
            RuntimeError: API 호출 실패 시
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

    @staticmethod
    async def _search_for_claim(
        client: "httpx.AsyncClient",
        claim: Claim,
        settings: "Settings",
    ) -> NewsMatchResult:
        """개별 주장에 대해 뉴스를 검색합니다."""
        # 빅카인즈 API 요청
        request_body = {
            "access_key": settings.bigkinds_api_key,
            "argument": {
                "query": claim.text,
                "published_at": {
                    "from": "2024-01-01",
                    "until": "2026-12-31",
                },
                "sort": {"date": "desc"},
                "hilight": 200,
                "return_from": 0,
                "return_size": 5,
            },
        }

        response = await client.post(
            settings.bigkinds_base_url,
            json=request_body,
        )
        response.raise_for_status()
        data = response.json()

        # 응답 파싱
        documents = data.get("return_object", {}).get("documents", [])
        articles = [
            NewsArticle(
                title=doc.get("title", ""),
                content=doc.get("content", "")[:500],
                source=doc.get("provider", ""),
                published_at=doc.get("published_at", ""),
                url=doc.get("provider_link_page", ""),
                relevance_score=float(doc.get("score", 0.0)),
            )
            for doc in documents
        ]

        return NewsMatchResult(
            claim_id=claim.id,
            articles=articles,
            match_count=len(articles),
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
                        title="GDP 성장률 3.5% 기록",
                        content="한국은행 발표에 따르면 올해 GDP 성장률은 3.5%로 집계되었다.",
                        source="한국경제",
                        published_at="2026-03-20",
                        url="https://example.com/news/1",
                        relevance_score=0.85,
                    ),
                    NewsArticle(
                        title="경제성장률 전망 하향 조정",
                        content="IMF가 한국 경제성장률 전망을 4%에서 3.2%로 하향 조정했다.",
                        source="연합뉴스",
                        published_at="2026-03-18",
                        url="https://example.com/news/2",
                        relevance_score=0.72,
                    ),
                ],
                match_count=2,
            ))
        return results
