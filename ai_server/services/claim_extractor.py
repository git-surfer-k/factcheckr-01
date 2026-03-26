# @TASK P2-R4-T1 - 주장 추출 서비스
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# OpenAI API를 사용하여 텍스트에서 팩트체크가 필요한 주장을 추출합니다.
# 추출된 주장은 카테고리 분류와 함께 반환됩니다.

from __future__ import annotations

import json
import logging
from abc import ABC, abstractmethod

from models.schemas import (
    Claim,
    ClaimExtractionResult,
    TranscriptResult,
)
from config.settings import get_settings

logger = logging.getLogger(__name__)

# 주장 추출용 시스템 프롬프트
EXTRACTION_SYSTEM_PROMPT = """당신은 팩트체크 전문가입니다.
주어진 텍스트에서 사실 확인이 필요한 주장을 추출하세요.

규칙:
1. 의견이 아닌 사실 주장만 추출합니다.
2. 검증 가능한 구체적인 주장만 포함합니다.
3. 각 주장에 적절한 카테고리(정치, 경제, 사회, 과학, 국제 등)를 지정합니다.

JSON 배열로 반환하세요:
[
  {
    "text": "주장 내용",
    "context": "주장이 나온 전후 맥락",
    "category": "카테고리"
  }
]
"""


class BaseClaimExtractor(ABC):
    """주장 추출 인터페이스"""

    @abstractmethod
    async def extract_claims(self, transcript: TranscriptResult) -> ClaimExtractionResult:
        """텍스트에서 팩트체크 대상 주장을 추출합니다."""
        ...


class OpenAIClaimExtractor(BaseClaimExtractor):
    """OpenAI API를 사용한 주장 추출기"""

    async def extract_claims(self, transcript: TranscriptResult) -> ClaimExtractionResult:
        """
        OpenAI API로 텍스트에서 주장을 추출합니다.

        Args:
            transcript: 음성 인식 결과 텍스트

        Returns:
            ClaimExtractionResult: 추출된 주장 목록

        Raises:
            RuntimeError: API 호출 실패 시
        """
        from openai import AsyncOpenAI

        settings = get_settings()

        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY가 설정되지 않았습니다.")

        client = AsyncOpenAI(api_key=settings.openai_api_key)

        try:
            logger.info("주장 추출 시작 (텍스트 길이: %d자)", len(transcript.text))

            response = await client.chat.completions.create(
                model=settings.openai_model,
                messages=[
                    {"role": "system", "content": EXTRACTION_SYSTEM_PROMPT},
                    {"role": "user", "content": transcript.text},
                ],
                temperature=0.1,
                response_format={"type": "json_object"},
            )

            # 응답 파싱
            content = response.choices[0].message.content or "[]"
            parsed = json.loads(content)

            # 응답이 dict이고 "claims" 키가 있는 경우 처리
            raw_claims = parsed if isinstance(parsed, list) else parsed.get("claims", [])

            # 구간 시간 정보 매칭
            claims = []
            for raw in raw_claims:
                claim = Claim(
                    text=raw.get("text", ""),
                    context=raw.get("context", ""),
                    category=raw.get("category", ""),
                )
                # 텍스트 구간과 매칭하여 시간 정보 추가
                claim = self._match_timestamp(claim, transcript)
                claims.append(claim)

            result = ClaimExtractionResult(
                claims=claims,
                total_count=len(claims),
            )

            logger.info("주장 추출 완료: %d개 주장", len(claims))
            return result

        except json.JSONDecodeError as e:
            logger.error("주장 추출 응답 파싱 실패: %s", str(e))
            raise RuntimeError(f"주장 추출 응답 파싱 실패: {str(e)}") from e
        except Exception as e:
            logger.error("주장 추출 실패: %s", str(e))
            raise RuntimeError(f"주장 추출 실패: {str(e)}") from e

    @staticmethod
    def _match_timestamp(claim: Claim, transcript: TranscriptResult) -> Claim:
        """주장 텍스트와 가장 유사한 구간의 시간 정보를 매칭합니다."""
        for segment in transcript.segments:
            if claim.text[:20] in segment.text or segment.text in claim.text:
                claim.timestamp_start = segment.start
                claim.timestamp_end = segment.end
                break
        return claim


class MockClaimExtractor(BaseClaimExtractor):
    """테스트용 가짜 주장 추출기"""

    async def extract_claims(self, transcript: TranscriptResult) -> ClaimExtractionResult:
        """테스트용 가짜 주장을 반환합니다."""
        claims = [
            Claim(
                text="GDP 성장률이 5%를 넘었다",
                context="정부 경제 정책 발표",
                category="경제",
                timestamp_start=10.0,
                timestamp_end=20.0,
            ),
        ]
        return ClaimExtractionResult(
            claims=claims,
            total_count=len(claims),
        )
