# @TASK P2-R4-T1 - Pydantic 스키마 정의
# @SPEC docs/planning/02-trd.md#영상-분석-파이프라인
#
# 파이프라인 전체에서 사용하는 데이터 모델입니다.
# 각 서비스의 입출력을 명확하게 정의합니다.

from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, HttpUrl


# ---------- 분석 상태 ----------

class AnalysisStatus(str, Enum):
    """분석 파이프라인의 진행 상태"""
    PENDING = "pending"
    DOWNLOADING = "downloading"
    TRANSCRIBING = "transcribing"
    EXTRACTING = "extracting"
    MATCHING = "matching"
    VERIFYING = "verifying"
    COMPLETED = "completed"
    FAILED = "failed"


# ---------- 요청/응답 ----------

class AnalyzeRequest(BaseModel):
    """분석 요청 스키마"""
    youtube_url: str = Field(..., description="분석할 유튜브 영상 URL")


class AnalyzeResponse(BaseModel):
    """분석 요청 응답 (태스크 ID 반환)"""
    task_id: str = Field(..., description="분석 태스크 고유 ID")
    status: AnalysisStatus = Field(default=AnalysisStatus.PENDING)
    message: str = Field(default="분석이 시작되었습니다.")


class StatusResponse(BaseModel):
    """분석 상태 조회 응답"""
    task_id: str
    status: AnalysisStatus
    current_step: str = Field(default="", description="현재 진행 중인 단계 설명")
    progress: float = Field(default=0.0, description="진행률 (0.0 ~ 1.0)")
    result: AnalysisResult | None = Field(default=None, description="완료 시 분석 결과")
    error: str | None = Field(default=None, description="실패 시 에러 메시지")
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)


class ErrorResponse(BaseModel):
    """에러 응답 (프로젝트 규칙에 따른 형식)"""
    error: str
    code: str


# ---------- 파이프라인 중간 데이터 ----------

class DownloadResult(BaseModel):
    """오디오 다운로드 결과"""
    audio_path: str = Field(..., description="다운로드된 오디오 파일 경로")
    video_title: str = Field(default="", description="영상 제목")
    video_duration: float = Field(default=0.0, description="영상 길이(초)")
    channel_name: str = Field(default="", description="채널명")


class TranscriptResult(BaseModel):
    """음성 → 텍스트 변환 결과"""
    text: str = Field(..., description="전체 텍스트")
    segments: list[TranscriptSegment] = Field(default_factory=list, description="시간별 구간 텍스트")
    language: str = Field(default="ko", description="감지된 언어")


class TranscriptSegment(BaseModel):
    """텍스트의 시간별 구간"""
    start: float = Field(..., description="시작 시간(초)")
    end: float = Field(..., description="끝 시간(초)")
    text: str = Field(..., description="구간 텍스트")


class Claim(BaseModel):
    """추출된 주장"""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    text: str = Field(..., description="주장 텍스트")
    context: str = Field(default="", description="주장이 나온 맥락")
    timestamp_start: float | None = Field(default=None, description="영상 내 시작 시간")
    timestamp_end: float | None = Field(default=None, description="영상 내 끝 시간")
    category: str = Field(default="", description="주장 분류 (정치, 경제, 사회 등)")


class ClaimExtractionResult(BaseModel):
    """주장 추출 결과"""
    claims: list[Claim] = Field(default_factory=list)
    total_count: int = Field(default=0, description="추출된 주장 수")


class NewsArticle(BaseModel):
    """빅카인즈에서 검색된 뉴스 기사"""
    title: str = Field(..., description="기사 제목")
    content: str = Field(default="", description="기사 본문 요약")
    source: str = Field(default="", description="언론사")
    published_at: str = Field(default="", description="발행일")
    url: str = Field(default="", description="기사 URL")
    relevance_score: float = Field(default=0.0, description="관련도 점수")


class NewsMatchResult(BaseModel):
    """뉴스 매칭 결과 (주장 1개에 대한 관련 뉴스)"""
    claim_id: str = Field(..., description="대상 주장 ID")
    articles: list[NewsArticle] = Field(default_factory=list)
    match_count: int = Field(default=0, description="매칭된 기사 수")


class VerificationVerdict(str, Enum):
    """검증 판정 결과"""
    TRUE = "true"               # 사실
    MOSTLY_TRUE = "mostly_true"  # 대체로 사실
    HALF_TRUE = "half_true"      # 절반의 사실
    MISLEADING = "misleading"    # 오해 소지
    MOSTLY_FALSE = "mostly_false"  # 대체로 거짓
    FALSE = "false"              # 거짓
    UNVERIFIABLE = "unverifiable"  # 검증 불가


class ClaimVerification(BaseModel):
    """개별 주장 검증 결과"""
    claim_id: str
    claim_text: str
    verdict: VerificationVerdict
    confidence: float = Field(default=0.0, description="신뢰도 (0.0 ~ 1.0)")
    explanation: str = Field(default="", description="판정 근거 설명")
    supporting_articles: list[NewsArticle] = Field(default_factory=list)


class AnalysisResult(BaseModel):
    """최종 분석 결과"""
    video_title: str = Field(default="")
    channel_name: str = Field(default="")
    video_duration: float = Field(default=0.0)
    total_claims: int = Field(default=0)
    verifications: list[ClaimVerification] = Field(default_factory=list)
    overall_trust_score: float = Field(
        default=0.0,
        description="전체 신뢰도 점수 (0.0 ~ 100.0)",
    )
    summary: str = Field(default="", description="종합 요약")
    analyzed_at: datetime = Field(default_factory=datetime.now)


# TranscriptResult가 TranscriptSegment를 참조하므로 모델 재빌드
TranscriptResult.model_rebuild()
StatusResponse.model_rebuild()
