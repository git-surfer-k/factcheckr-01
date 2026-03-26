# @TASK P2-R4-T1 - 최종 검증 리포트 생성 서비스
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# OpenAI API를 사용하여 주장과 관련 뉴스를 비교하고
# 최종 팩트체크 판정을 생성합니다.

from __future__ import annotations

import json
import logging
from abc import ABC, abstractmethod

from models.schemas import (
    AnalysisResult,
    ClaimExtractionResult,
    ClaimVerification,
    DownloadResult,
    NewsMatchResult,
    VerificationVerdict,
)
from config.settings import get_settings

logger = logging.getLogger(__name__)

# 팩트체크 판정용 시스템 프롬프트
VERIFICATION_SYSTEM_PROMPT = """당신은 팩트체크 판정 전문가입니다.
주어진 주장과 관련 뉴스 기사를 비교하여 사실 여부를 판정하세요.

판정 기준:
- true: 뉴스 기사에서 해당 주장이 사실임을 확인
- mostly_true: 대체로 사실이나 약간의 부정확성 존재
- half_true: 부분적으로만 사실
- misleading: 사실이나 오해를 유발하는 방식으로 제시
- mostly_false: 대부분 사실이 아님
- false: 뉴스 기사에서 명확히 반박됨
- unverifiable: 관련 뉴스가 불충분하여 검증 불가

JSON으로 반환하세요:
{
  "verdict": "판정",
  "confidence": 0.0~1.0,
  "explanation": "판정 근거 설명"
}
"""


class BaseFactChecker(ABC):
    """팩트체크 인터페이스"""

    @abstractmethod
    async def verify(
        self,
        extraction_result: ClaimExtractionResult,
        news_matches: list[NewsMatchResult],
        download_result: DownloadResult,
    ) -> AnalysisResult:
        """주장과 뉴스를 대조하여 최종 검증 결과를 생성합니다."""
        ...


class OpenAIFactChecker(BaseFactChecker):
    """OpenAI API를 사용한 팩트체크"""

    async def verify(
        self,
        extraction_result: ClaimExtractionResult,
        news_matches: list[NewsMatchResult],
        download_result: DownloadResult,
    ) -> AnalysisResult:
        """
        각 주장을 관련 뉴스와 대조하여 판정합니다.

        Args:
            extraction_result: 추출된 주장들
            news_matches: 주장별 관련 뉴스
            download_result: 원본 영상 정보

        Returns:
            AnalysisResult: 최종 분석 결과 (개별 판정 + 종합 점수)

        Raises:
            RuntimeError: API 호출 실패 시
        """
        from openai import AsyncOpenAI

        settings = get_settings()

        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY가 설정되지 않았습니다.")

        client = AsyncOpenAI(api_key=settings.openai_api_key)

        # 주장 ID → 뉴스 매칭 결과 매핑
        news_by_claim: dict[str, NewsMatchResult] = {
            match.claim_id: match for match in news_matches
        }

        verifications: list[ClaimVerification] = []

        for claim in extraction_result.claims:
            news_match = news_by_claim.get(claim.id)
            try:
                verification = await self._verify_claim(client, claim, news_match, settings)
                verifications.append(verification)
            except Exception as e:
                logger.warning("주장 '%s' 검증 실패: %s", claim.text[:30], str(e))
                # 검증 실패 시 '검증 불가'로 처리
                verifications.append(ClaimVerification(
                    claim_id=claim.id,
                    claim_text=claim.text,
                    verdict=VerificationVerdict.UNVERIFIABLE,
                    confidence=0.0,
                    explanation=f"검증 중 오류 발생: {str(e)}",
                ))

        # 종합 신뢰도 점수 계산
        overall_score = self._calculate_trust_score(verifications)

        return AnalysisResult(
            video_title=download_result.video_title,
            channel_name=download_result.channel_name,
            video_duration=download_result.video_duration,
            total_claims=len(verifications),
            verifications=verifications,
            overall_trust_score=overall_score,
            summary=self._generate_summary(verifications, overall_score),
        )

    @staticmethod
    async def _verify_claim(client, claim, news_match, settings) -> ClaimVerification:
        """개별 주장을 검증합니다."""
        # 관련 뉴스 텍스트 구성
        if news_match and news_match.articles:
            news_text = "\n\n".join(
                f"[{a.source}] {a.title}\n{a.content}"
                for a in news_match.articles
            )
        else:
            news_text = "(관련 뉴스 없음)"

        user_prompt = (
            f"주장: {claim.text}\n"
            f"맥락: {claim.context}\n"
            f"카테고리: {claim.category}\n\n"
            f"관련 뉴스:\n{news_text}"
        )

        response = await client.chat.completions.create(
            model=settings.openai_model,
            messages=[
                {"role": "system", "content": VERIFICATION_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.1,
            response_format={"type": "json_object"},
        )

        content = response.choices[0].message.content or "{}"
        parsed = json.loads(content)

        return ClaimVerification(
            claim_id=claim.id,
            claim_text=claim.text,
            verdict=VerificationVerdict(parsed.get("verdict", "unverifiable")),
            confidence=float(parsed.get("confidence", 0.0)),
            explanation=parsed.get("explanation", ""),
            supporting_articles=news_match.articles if news_match else [],
        )

    @staticmethod
    def _calculate_trust_score(verifications: list[ClaimVerification]) -> float:
        """주장별 판정 결과를 기반으로 종합 신뢰도 점수를 계산합니다."""
        if not verifications:
            return 0.0

        # 판정별 가중치 (100점 만점)
        verdict_scores = {
            VerificationVerdict.TRUE: 100.0,
            VerificationVerdict.MOSTLY_TRUE: 80.0,
            VerificationVerdict.HALF_TRUE: 50.0,
            VerificationVerdict.MISLEADING: 30.0,
            VerificationVerdict.MOSTLY_FALSE: 15.0,
            VerificationVerdict.FALSE: 0.0,
            VerificationVerdict.UNVERIFIABLE: 50.0,
        }

        total_score = sum(
            verdict_scores.get(v.verdict, 50.0) * v.confidence
            for v in verifications
        )
        total_confidence = sum(v.confidence for v in verifications)

        if total_confidence == 0:
            return 50.0

        return round(total_score / total_confidence, 1)

    @staticmethod
    def _generate_summary(verifications: list[ClaimVerification], score: float) -> str:
        """종합 요약 텍스트를 생성합니다."""
        total = len(verifications)
        if total == 0:
            return "검증할 주장이 없습니다."

        # 판정 카운트
        verdicts = {}
        for v in verifications:
            verdicts[v.verdict.value] = verdicts.get(v.verdict.value, 0) + 1

        verdict_summary = ", ".join(f"{k}: {cnt}건" for k, cnt in verdicts.items())
        return (
            f"총 {total}개 주장 검증 완료. "
            f"종합 신뢰도: {score}점. "
            f"판정 분포: {verdict_summary}."
        )


class MockFactChecker(BaseFactChecker):
    """테스트용 가짜 팩트체커"""

    async def verify(
        self,
        extraction_result: ClaimExtractionResult,
        news_matches: list[NewsMatchResult],
        download_result: DownloadResult,
    ) -> AnalysisResult:
        """테스트용 가짜 검증 결과를 반환합니다."""
        verifications = []
        for claim in extraction_result.claims:
            verifications.append(ClaimVerification(
                claim_id=claim.id,
                claim_text=claim.text,
                verdict=VerificationVerdict.MOSTLY_FALSE,
                confidence=0.85,
                explanation="관련 뉴스에 따르면 GDP 성장률은 3.5%로 5%와 차이가 있습니다.",
                supporting_articles=[],
            ))

        return AnalysisResult(
            video_title=download_result.video_title,
            channel_name=download_result.channel_name,
            video_duration=download_result.video_duration,
            total_claims=len(verifications),
            verifications=verifications,
            overall_trust_score=15.0,
            summary=f"총 {len(verifications)}개 주장 검증 완료. 종합 신뢰도: 15.0점.",
        )
