# frozen_string_literal: true

# @TASK P2-S1-V - 홈 화면 연결점 검증
# @TASK P2-S3-V - 리포트 상세 연결점 검증
# 화면 UI, API 엔드포인트, 라우트, 인증이 올바르게 연결되었는지 검증하는 통합 테스트
require "test_helper"

class VerificationTest < ActionDispatch::IntegrationTest
  # ========== P2-S1-V: 홈 화면 연결점 검증 ==========

  # 검증 1-1: fact_checks API 엔드포인트가 routes.rb에 존재하는가?
  test "P2-S1-V-1: GET /api/v1/fact_checks 라우트가 존재한다" do
    assert_routing(
      { path: "/api/v1/fact_checks", method: :get },
      { controller: "api/v1/fact_checks", action: "index" }
    )
  end

  # 검증 1-2: 홈 화면에서 최근 팩트체크 목록 렌더링 시 필요한 필드가 뷰에 존재하는가?
  test "P2-S1-V-2: 홈 화면이 fact_checks 필드를 사용한다 (id, video_title, video_thumbnail, overall_score, created_at)" do
    user = User.create!(
      email: "home_test@example.com",
      name: "홈 테스트",
      user_type: 0,
      is_active: true
    )

    channel = Channel.create!(
      youtube_channel_id: "UC_home_test_channel",
      name: "테스트 채널",
      description: "테스트용 채널",
      subscriber_count: 100_000,
      trust_score: 50.0,
      total_checks: 5,
      thumbnail_url: nil
    )

    fact_check = FactCheck.create!(
      user: user,
      channel: channel,
      youtube_url: "https://www.youtube.com/watch?v=test_home_01",
      video_title: "[테스트] 홈 화면 검증 영상",
      video_thumbnail: "https://example.com/thumb.jpg",
      summary: "테스트 요약",
      overall_score: 75.5,
      analysis_detail: "테스트 분석",
      status: :completed,
      completed_at: Time.current
    )

    # 웹 세션 생성 (로그인 상태 시뮬레이션)
    session = Session.create!(user: user)

    # 홈 페이지에 로그인 상태로 접근 (세션 쿠키 설정)
    get root_path, headers: { "Cookie" => "session_token=#{session.token}" }
    assert_response :success

    # fact_check의 id가 HTML에 포함되는지 확인
    assert_select "a[href='#{report_path(fact_check.id)}']"

    # video_title이 표시되는지 확인
    assert_select "a[href='#{report_path(fact_check.id)}'] p", text: /홈 화면 검증 영상/

    # video_thumbnail이 렌더링되는지 확인 (img src 태그에 포함)
    assert_select "a[href='#{report_path(fact_check.id)}'] img[src='https://example.com/thumb.jpg']"

    # overall_score가 표시되는지 확인
    assert_select "a[href='#{report_path(fact_check.id)}']", text: /75\.5/

    # created_at이 상대 시간으로 표시되는지 확인
    assert_select "a[href='#{report_path(fact_check.id)}']", text: /분 전|초 전|시간 전/

    # 정리
    fact_check.destroy
    channel.destroy
    user.destroy
  end

  # 검증 1-3: /analyze/:id 라우트가 존재하는가?
  test "P2-S1-V-3: /analyze/:id 라우트가 존재한다" do
    assert_routing(
      { path: "/analyze/test-id", method: :get },
      { controller: "pages", action: "analyze", id: "test-id" }
    )
  end

  # 검증 1-4: /reports/:id 라우트가 존재하는가?
  test "P2-S1-V-4: /reports/:id 라우트가 존재한다" do
    assert_routing(
      { path: "/reports/test-id", method: :get },
      { controller: "reports", action: "show", id: "test-id" }
    )
  end

  # 검증 1-5: 홈 화면에서 최근 팩트체크 클릭 시 /reports/:id로 이동하는가?
  test "P2-S1-V-5: 홈 화면의 최근 검사 항목이 /reports/:id로 이동한다" do
    user = User.create!(
      email: "home_nav_test@example.com",
      name: "홈 네비게이션 테스트",
      user_type: 0,
      is_active: true
    )

    channel = Channel.create!(
      youtube_channel_id: "UC_home_nav_test",
      name: "테스트 채널",
      description: "테스트용",
      subscriber_count: 50_000,
      trust_score: 60.0,
      total_checks: 3,
      thumbnail_url: nil
    )

    fact_check = FactCheck.create!(
      user: user,
      channel: channel,
      youtube_url: "https://www.youtube.com/watch?v=test_nav_01",
      video_title: "네비게이션 테스트 영상",
      video_thumbnail: "https://example.com/thumb.jpg",
      summary: "네비 테스트",
      overall_score: 50.0,
      analysis_detail: "네비 분석",
      status: :completed,
      completed_at: Time.current
    )

    session = Session.create!(user: user)

    # 홈 페이지에서 최근 검사 링크 클릭 시뮬레이션
    get root_path, headers: { "Cookie" => "session_token=#{session.token}" }
    assert_select "a[href='#{report_path(fact_check.id)}']"

    # 실제 링크가 올바른 경로로 향하는지 확인
    get report_path(fact_check.id)
    assert_response :success

    # 정리
    fact_check.destroy
    channel.destroy
    user.destroy
  end

  # 검증 1-6: 홈 화면이 인증 없이 접근 가능한가? (로그인 사용자는 목록, 미로그인은 빈 상태)
  test "P2-S1-V-6: 홈 화면이 인증 요구사항을 적용한다 (로그인/미로그인 구분)" do
    # 미로그인 상태로 접근해도 전체 팩트체크 표시
    get root_path
    assert_response :success

    # 로그인 사용자 생성
    user = User.create!(
      email: "auth_test@example.com",
      name: "인증 테스트",
      user_type: 0,
      is_active: true
    )

    channel = Channel.create!(
      youtube_channel_id: "UC_auth_test",
      name: "테스트",
      description: "테스트",
      subscriber_count: 1000,
      trust_score: 50.0,
      total_checks: 1,
      thumbnail_url: nil
    )

    FactCheck.create!(
      user: user,
      channel: channel,
      youtube_url: "https://www.youtube.com/watch?v=auth_test_01",
      video_title: "인증 테스트",
      video_thumbnail: "https://example.com/thumb.jpg",
      summary: "테스트",
      overall_score: 50.0,
      analysis_detail: "테스트",
      status: :completed,
      completed_at: Time.current
    )

    session = Session.create!(user: user)

    # 로그인 상태로 접근
    get root_path, headers: { "Cookie" => "session_token=#{session.token}" }
    assert_response :success
    # 로그인 상태에서 최근 검사 목록 표시
    assert_select "[data-component='recent-checks']"

    # 정리
    FactCheck.where(user_id: user.id).destroy_all
    channel.destroy
    user.destroy
  end

  # ========== P2-S3-V: 리포트 상세 연결점 검증 ==========

  setup do
    # 테스트용 데이터 생성 (리포트 상세 검증에 사용)
    @channel = Channel.create!(
      youtube_channel_id: "UC_verification_channel",
      name: "검증 채널",
      description: "검증용 채널",
      subscriber_count: 300_000,
      trust_score: 65.0,
      total_checks: 8,
      thumbnail_url: "https://example.com/channel_thumb.jpg"
    )

    @user = User.create!(
      email: "report_verification@example.com",
      name: "리포트 검증",
      user_type: 0,
      is_active: true
    )

    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=verify_report_01",
      video_title: "[팩트체크] 연결점 검증 영상",
      video_thumbnail: "https://example.com/video_thumb.jpg",
      transcript: "영상 자막 텍스트",
      summary: "이 영상의 주요 주장 3건을 팩트체크한 결과를 요약합니다.",
      overall_score: 60.5,
      analysis_detail: "세 가지 주장 중 하나는 사실, 하나는 절반 사실, 하나는 거짓으로 판정되었습니다.",
      status: :completed,
      completed_at: Time.current
    )

    @claim = Claim.create!(
      fact_check: @fact_check,
      claim_text: "경제 성장률이 지난해 대비 2배 증가했다",
      verdict: :mostly_true,
      confidence: 0.82,
      explanation: "통계청 발표 데이터와 대부분 일치하지만, 계절 조정 변수에 따라 달라질 수 있습니다.",
      timestamp_start: 45,
      timestamp_end: 72
    )

    @news_source = NewsSource.create!(
      claim: @claim,
      title: "2024년 경제 성장률 예상치 상향",
      url: "https://news.example.com/economy/2024-growth",
      publisher: "경제신문",
      author: "기자명",
      published_at: 1.week.ago,
      relevance_score: 0.88
    )
  end

  # 검증 3-1: GET /api/v1/fact_checks/:id 엔드포인트가 routes.rb에 존재하는가?
  test "P2-S3-V-1: GET /api/v1/fact_checks/:id 라우트가 존재한다" do
    assert_routing(
      { path: "/api/v1/fact_checks/test-id", method: :get },
      { controller: "api/v1/fact_checks", action: "show", id: "test-id" }
    )
  end

  # 검증 3-2: GET /api/v1/fact_checks/:id/claims 엔드포인트가 routes.rb에 존재하는가?
  test "P2-S3-V-2: GET /api/v1/fact_checks/:id/claims 라우트가 존재한다" do
    assert_routing(
      { path: "/api/v1/fact_checks/test-id/claims", method: :get },
      { controller: "api/v1/claims", action: "index", fact_check_id: "test-id" }
    )
  end

  # 검증 3-3: 리포트 상세 페이지에서 fact_check의 필드가 사용되는가?
  test "P2-S3-V-3: 리포트 상세 페이지가 fact_checks의 필드를 사용한다 (id, video_title, summary, overall_score, analysis_detail)" do
    get report_path(@fact_check.id)
    assert_response :success

    # video_title이 헤더에 표시되는지 확인
    assert_select "[data-component='report-header'] [data-field='video-title']", text: /팩트체크/

    # overall_score가 점수 배지에 표시되는지 확인
    assert_select "[data-field='overall-score']", text: /60/

    # summary가 콘텐츠 요약 탭에 표시되는지 확인
    assert_select "[data-panel='summary'] [data-field='summary-text']", text: /요약합니다/

    # analysis_detail이 팩트 점수 탭에 표시되는지 확인
    assert_select "[data-panel='score']", text: /절반 사실/
  end

  # 검증 3-4: 리포트 상세 페이지에서 claims의 필드가 사용되는가?
  test "P2-S3-V-4: 리포트 상세 페이지가 claims의 필드를 사용한다 (claim_text, verdict, confidence, explanation)" do
    get report_path(@fact_check.id)
    assert_response :success

    # claim_text가 ClaimCard에 표시되는지 확인
    assert_select "[data-component='claim-card'] [data-field='claim-text']", text: /경제 성장률/

    # verdict가 ClaimCard에 표시되는지 확인
    assert_select "[data-component='claim-card'] [data-field='verdict']"

    # confidence가 확신도 바에 표시되는지 확인
    assert_select "[data-component='confidence-bar']"

    # explanation이 ClaimCard에 표시되는지 확인
    assert_select "[data-component='claim-card']", text: /계절 조정/
  end

  # 검증 3-5: 리포트 상세 페이지에서 news_sources의 필드가 사용되는가?
  test "P2-S3-V-5: 리포트 상세 페이지가 news_sources의 필드를 사용한다 (title, url, publisher, published_at)" do
    get report_path(@fact_check.id)
    assert_response :success

    # news title이 뉴스 항목에 표시되는지 확인
    assert_select "[data-component='news-item'] [data-field='news-title']", text: /경제 성장률/

    # news URL이 링크의 href에 포함되는지 확인
    assert_select "[data-component='news-item'] a[href='https://news.example.com/economy/2024-growth']"

    # publisher가 표시되는지 확인
    assert_select "[data-component='news-item']", text: /경제신문/

    # published_at이 날짜 형식으로 표시되는지 확인
    assert_select "[data-component='news-item']", text: /\d{4}\.\d{2}\.\d{2}/
  end

  # 검증 3-6: 채널 정보 탭에서 채널 상세 라우트 또는 링크가 존재하는가?
  test "P2-S3-V-6: 리포트 상세 페이지의 채널 정보 탭이 채널 상세 링크를 포함한다" do
    get report_path(@fact_check.id)
    assert_response :success

    # 채널 정보 컴포넌트 존재 확인
    assert_select "[data-component='channel-info']"

    # 채널 상세 보기 버튼이 존재하는지 확인
    assert_select "[data-component='channel-info']", text: /채널 상세 보기/
  end

  # 검증 3-7: 리포트 상세 페이지에 다운로드 버튼이 있는가?
  test "P2-S3-V-7: 리포트 상세 페이지가 다운로드 버튼을 포함한다" do
    get report_path(@fact_check.id)
    assert_response :success

    # 다운로드 버튼 존재 확인
    assert_select "[data-component='download-button']"
  end

  # 검증 3-8: 리포트 상세 페이지의 5개 탭이 모두 동작하는가?
  test "P2-S3-V-8: 리포트 상세 페이지의 5개 탭이 모두 표시된다" do
    get report_path(@fact_check.id)
    assert_response :success

    # 5개 탭 존재 확인
    assert_select "[data-tab='summary']"
    assert_select "[data-tab='score']"
    assert_select "[data-tab='claims']"
    assert_select "[data-tab='news']"
    assert_select "[data-tab='channel']"

    # 5개 탭 패널 존재 확인
    assert_select "[data-panel='summary']"
    assert_select "[data-panel='score']"
    assert_select "[data-panel='claims']"
    assert_select "[data-panel='news']"
    assert_select "[data-panel='channel']"
  end

  # 검증 3-9: 리포트 상세 페이지에서 존재하지 않는 ID로 접근하면 404가 반환되는가?
  test "P2-S3-V-9: 존재하지 않는 리포트 ID로 접근하면 404가 반환된다" do
    get report_path("nonexistent-report-id-99999")
    assert_response :not_found
  end

  # 검증 3-10: 리포트 상세 페이지의 HTML에 필요한 모든 데이터 속성이 존재하는가?
  test "P2-S3-V-10: 리포트 상세 페이지의 모든 핵심 컴포넌트가 존재한다" do
    get report_path(@fact_check.id)
    assert_response :success

    # 핵심 컴포넌트 존재 확인
    assert_select "[data-component='report-header']"
    assert_select "[data-component='score-badge']"
    assert_select "[data-component='report-tabs']"
    assert_select "[data-component='ai-disclaimer']"
    assert_select "[data-component='claim-card']"
    assert_select "[data-component='news-item']"
    assert_select "[data-component='channel-info']"
    assert_select "[data-component='download-button']"
  end

  teardown do
    # 테스트 데이터 정리 (외래 키 의존성 순서: NewsSource → Claim → FactCheck → Channel/User)
    NewsSource.where(claim_id: @claim&.id).delete_all
    Claim.where(fact_check_id: @fact_check&.id).delete_all
    FactCheck.where(id: @fact_check&.id).delete_all
    Channel.where(id: @channel&.id).delete_all
    User.where(id: @user&.id).delete_all
  end
end
