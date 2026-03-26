# frozen_string_literal: true

# @TASK P2-S3-T1 - 리포트 상세 화면 UI 통합 테스트
# @SPEC specs/screens/b2c-report-detail.yaml
# 리포트 헤더, 5탭 구조, ClaimCard, NewsLinks, AI 면책 고지를 검증한다.
require "test_helper"

class ReportPageTest < ActionDispatch::IntegrationTest
  # 테스트용 픽스처 데이터를 사전에 준비한다.
  setup do
    @channel = Channel.create!(
      youtube_channel_id: "UC_test_report_channel",
      name: "OO경제TV",
      description: "경제 뉴스 채널",
      subscriber_count: 450_000,
      trust_score: 32.0,
      total_checks: 10,
      thumbnail_url: nil
    )

    @user = User.create!(
      email: "report_test@example.com",
      name: "리포트 테스터",
      user_type: 0,
      is_active: true
    )

    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=test_report_01",
      video_title: "[긴급] 부동산 폭락 시작됐다",
      summary: "이 영상에서는 부동산 시장이 폭락하고 있다고 주장하며, 서울 아파트 거래량 감소와 가격 하락 데이터를 제시합니다.",
      overall_score: 32.0,
      analysis_detail: "부동산 관련 주장 3건 중 1건 사실, 2건 거짓으로 판정되었습니다.",
      status: :completed,
      completed_at: Time.current
    )

    @claim = Claim.create!(
      fact_check: @fact_check,
      claim_text: "서울 아파트 거래량이 50% 감소했다",
      verdict: :false_claim,
      confidence: 0.85,
      explanation: "국토교통부 실거래가 공개시스템 데이터와 일치하지 않습니다.",
      timestamp_start: 120,
      timestamp_end: 145
    )

    @news_source = NewsSource.create!(
      claim: @claim,
      title: "서울 아파트 거래량 현황 분석",
      url: "https://news.example.com/article/12345",
      publisher: "경제신문",
      author: "홍길동",
      published_at: 3.days.ago,
      relevance_score: 0.9
    )
  end

  # 리포트 상세 페이지가 정상 응답(200)을 반환하는지 확인
  test "리포트 상세 페이지가 정상적으로 로드된다" do
    get report_path(@fact_check.id)
    assert_response :success
  end

  # 리포트 헤더 영역이 존재하는지 확인
  test "리포트 헤더 컴포넌트가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='report-header']"
  end

  # 영상 제목이 헤더에 표시되는지 확인
  test "영상 제목이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='report-header']" do
      assert_select "[data-field='video-title']", text: /긴급/
    end
  end

  # 채널명이 헤더에 표시되는지 확인
  test "채널명이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-field='channel-name']", text: /OO경제TV/
  end

  # 팩트체크 점수(ScoreBadge)가 표시되는지 확인
  test "전체 점수 배지가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='score-badge']"
  end

  # 점수 숫자가 표시되는지 확인
  test "점수 숫자가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-field='overall-score']", text: /32/
  end

  # 5개 탭이 모두 표시되는지 확인
  test "5개 탭이 모두 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='report-tabs']"
    assert_select "[data-tab]", count: 5
  end

  # 각 탭의 data 속성이 올바른지 확인
  test "콘텐츠 요약 탭이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-tab='summary']"
  end

  test "팩트 점수 탭이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-tab='score']"
  end

  test "주장별 검증 탭이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-tab='claims']"
  end

  test "근거 뉴스 탭이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-tab='news']"
  end

  test "채널 정보 탭이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-tab='channel']"
  end

  # 기본 탭(콘텐츠 요약) 패널이 표시되는지 확인
  test "기본 탭 패널(콘텐츠 요약)이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-panel='summary']"
  end

  # 콘텐츠 요약 텍스트가 표시되는지 확인
  test "콘텐츠 요약 내용이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-panel='summary']" do
      assert_select "[data-field='summary-text']"
    end
  end

  # 팩트 점수 패널에 분석 상세가 표시되는지 확인
  test "팩트 점수 패널이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-panel='score']"
  end

  # 주장별 검증 패널에 ClaimCard가 표시되는지 확인
  test "주장별 검증 패널이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-panel='claims']"
  end

  # ClaimCard 컴포넌트가 존재하는지 확인
  test "ClaimCard 컴포넌트가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='claim-card']"
  end

  # 주장 원문이 ClaimCard 안에 표시되는지 확인
  test "주장 원문이 ClaimCard에 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='claim-card']" do
      assert_select "[data-field='claim-text']", text: /서울 아파트/
    end
  end

  # 판정 결과(verdict)가 표시되는지 확인
  test "판정 결과가 ClaimCard에 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='claim-card']" do
      assert_select "[data-field='verdict']"
    end
  end

  # 확신도 바가 표시되는지 확인
  test "확신도 바가 ClaimCard에 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='claim-card']" do
      assert_select "[data-component='confidence-bar']"
    end
  end

  # 근거 뉴스 패널이 존재하는지 확인
  test "근거 뉴스 패널이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-panel='news']"
  end

  # NewsSource 항목이 표시되는지 확인
  test "뉴스 소스 항목이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='news-item']"
  end

  # 뉴스 제목이 표시되는지 확인
  test "뉴스 기사 제목이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='news-item']" do
      assert_select "[data-field='news-title']", text: /서울 아파트/
    end
  end

  # 뉴스 링크가 새 탭으로 열리는지 확인 (target="_blank")
  test "뉴스 링크가 새 탭으로 열린다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='news-item'] a[target='_blank']"
  end

  # 채널 정보 패널이 존재하는지 확인
  test "채널 정보 패널이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-panel='channel']"
  end

  # 채널 정보 컴포넌트가 표시되는지 확인
  test "채널 정보 컴포넌트가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='channel-info']"
  end

  # 다운로드 버튼이 표시되는지 확인
  test "다운로드 버튼이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-button']"
  end

  # AI 면책 고지(disclaimer)가 표시되는지 확인
  test "AI 검증 면책 고지가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='ai-disclaimer']"
  end

  # AI 면책 고지 텍스트가 올바른지 확인
  test "AI 면책 고지 텍스트가 포함된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='ai-disclaimer']", text: /AI/
  end

  # 페이지 타이틀이 올바르게 설정되는지 확인
  test "페이지 타이틀이 영상 제목을 포함한다" do
    get report_path(@fact_check.id)
    assert_select "title", text: /팩트체크 리포트/
  end

  # 존재하지 않는 리포트 요청 시 404 처리 확인
  test "존재하지 않는 리포트는 404를 반환한다" do
    get report_path("nonexistent-id-00000000")
    assert_response :not_found
  end

  # 탭 전환을 위한 JavaScript 데이터 속성이 존재하는지 확인
  test "탭 전환을 위한 데이터 컨트롤러 속성이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-controller='report-tabs']"
  end

  # 분석 일시가 표시되는지 확인
  test "분석 일시가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-field='created-at']"
  end

  teardown do
    # 테스트 데이터 정리 (NewsSource → Claim → FactCheck → Channel/User 순)
    NewsSource.where(claim_id: @claim&.id).delete_all
    Claim.where(fact_check_id: @fact_check&.id).delete_all
    FactCheck.where(id: @fact_check&.id).delete_all
    Channel.where(id: @channel&.id).delete_all
    User.where(id: @user&.id).delete_all
  end
end
