# frozen_string_literal: true

# @TASK P5-S2-T1 - B2B 대시보드 화면 통합 테스트
# @SPEC specs/screens/b2b-dashboard.yaml
# 대시보드 라우트, 인증 보호, 컴포넌트 렌더링을 검증한다.
require "test_helper"

class B2bDashboardTest < ActionDispatch::IntegrationTest
  # 트랜잭션으로 각 테스트 후 자동 롤백 (DB 잠금 방지)
  self.use_transactional_tests = true

  setup do
    # 테스트용 B2B 사용자 생성
    @user = User.create!(
      email: "corp_dashboard@example.com",
      user_type: :b2b,
      is_active: true
    )
    # 세션 생성 후 쿠키에 저장 (B2B 세션 토큰 방식)
    @session_record = @user.create_session!
  end

  # 로그인 세션 없이 접근하면 로그인으로 리다이렉트되어야 함
  test "미인증 사용자는 로그인 페이지로 리다이렉트된다" do
    get b2b_dashboard_path
    assert_redirected_to b2b_login_path
  end

  # 세션 쿠키로 로그인한 사용자는 대시보드에 접근 가능해야 함
  test "인증된 B2B 사용자는 대시보드에 접근할 수 있다" do
    # 세션 쿠키 설정
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_response :success
  end

  # B2B 레이아웃이 적용되어야 함
  test "B2B 전용 레이아웃이 적용된다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_select "[data-layout='b2b']"
  end

  # 사이드바 네비게이션이 표시되어야 함
  test "사이드바 네비게이션이 표시된다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_select "[data-nav='b2b-sidebar']"
  end

  # 사이드바에 주요 메뉴 항목이 있어야 함
  test "사이드바에 대시보드, 새 리포트, 결제 관리 메뉴가 있다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_match "대시보드", response.body
    assert_match "새 리포트", response.body
    assert_match "결제 관리", response.body
  end

  # 구독 상태 카드가 표시되어야 함
  test "구독 상태 카드가 표시된다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_select "[data-component='subscription-card']"
  end

  # 최근 리포트 목록 컴포넌트가 표시되어야 함
  test "최근 리포트 목록 섹션이 표시된다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_select "[data-component='recent-reports']"
  end

  # 새 리포트 요청 버튼(CTA)이 표시되어야 함
  test "새 리포트 요청 버튼이 표시된다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_select "[data-action='new-report']"
  end

  # 리포트가 있을 때 목록에 리포트 항목이 표시되어야 함
  test "리포트가 있으면 목록에 표시된다" do
    cookies[:b2b_session_token] = @session_record.token
    B2bReport.create!(
      user: @user,
      company_name: "테스트 기업",
      industry: "IT",
      status: :completed
    )
    get b2b_dashboard_path
    assert_match "테스트 기업", response.body
  end

  # 리포트가 없을 때 빈 상태 안내 문구가 표시되어야 함
  test "리포트가 없으면 빈 상태 안내 문구가 표시된다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_select "[data-component='empty-reports']"
  end

  # 구독이 있을 때 플랜 정보가 표시되어야 함
  test "활성 구독이 있으면 플랜 정보가 표시된다" do
    cookies[:b2b_session_token] = @session_record.token
    Subscription.create!(
      user: @user,
      plan_type: :b2b_standard,
      status: :active,
      expires_at: 30.days.from_now
    )
    get b2b_dashboard_path
    assert_match "B2B Standard", response.body
  end

  # 라우트 매핑 검증
  test "B2B 대시보드 라우트가 올바르게 매핑된다" do
    assert_routing(
      { path: "/b2b/dashboard", method: :get },
      { controller: "b2b/dashboard", action: "index" }
    )
  end

  # Trust Blue 테마가 적용되어야 함
  test "Trust Blue 테마가 적용된다" do
    cookies[:b2b_session_token] = @session_record.token
    get b2b_dashboard_path
    assert_select "[data-theme='trust-blue']"
  end
end
