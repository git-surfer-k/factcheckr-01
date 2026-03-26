# frozen_string_literal: true

# @TASK P5-S5-T1 - B2B 결제 관리 화면 통합 테스트
# @SPEC specs/screens/b2b-billing.yaml
# B2B 결제 관리 페이지 렌더링, 라우트, 인증을 검증한다.
require "test_helper"

class B2bBillingTest < ActionDispatch::IntegrationTest
  # 각 테스트 전에 B2B 사용자와 구독 데이터를 생성한다.
  setup do
    @b2b_user = User.create!(
      email: "billing_test@corp.example.com",
      name: "결제 테스트 기업",
      user_type: :b2b,
      is_active: true
    )

    # 활성 B2B 구독 생성
    @subscription = Subscription.create!(
      user: @b2b_user,
      plan_type: :b2b_standard,
      status: :active,
      started_at: 1.month.ago,
      expires_at: 1.month.from_now
    )

    # B2B 세션 생성 (로그인 상태 시뮬레이션)
    @db_session = @b2b_user.sessions.create!
  end

  teardown do
    # 외래 키 의존성 순서대로 정리
    Subscription.where(user_id: @b2b_user&.id).delete_all
    Session.where(user_id: @b2b_user&.id).delete_all
    @b2b_user&.destroy
  end

  # 라우트 검증: GET /b2b/billing 라우트가 올바르게 매핑되는지 확인
  test "B2B 결제 관리 라우트가 올바르게 매핑된다" do
    assert_routing(
      { path: "/b2b/billing", method: :get },
      { controller: "b2b/billing", action: "index" }
    )
  end

  # 인증 검증: 로그인하지 않은 사용자는 접근할 수 없다
  test "비로그인 사용자는 결제 관리 페이지에 접근하면 리다이렉트된다" do
    get b2b_billing_path
    assert_response :redirect
  end

  # 정상 렌더링: 로그인한 B2B 사용자는 200 응답을 받는다
  test "로그인한 B2B 사용자는 결제 관리 페이지에 접근할 수 있다" do
    get b2b_billing_path, headers: session_headers
    assert_response :success
  end

  # 레이아웃 검증: B2B 전용 레이아웃이 적용되는지 확인
  test "B2B 전용 레이아웃이 적용된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-layout='b2b']"
    assert_select "[data-theme='trust-blue']"
  end

  # CurrentPlan 컴포넌트: 현재 구독 플랜 정보가 표시되는지 확인
  test "현재 구독 플랜 카드(CurrentPlan)가 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-component='current-plan']"
  end

  # CurrentPlan: 플랜 이름이 표시되는지 확인
  test "현재 플랜 이름이 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-field='plan-name']"
  end

  # CurrentPlan: 구독 상태(활성/만료)가 표시되는지 확인
  test "구독 상태가 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-field='plan-status']"
  end

  # CurrentPlan: 만료일이 표시되는지 확인
  test "구독 만료일이 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-field='expires-at']"
  end

  # PlanSelector 컴포넌트: 플랜 선택 섹션이 표시되는지 확인
  test "플랜 선택 섹션(PlanSelector)이 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-component='plan-selector']"
  end

  # PlanSelector: b2b_standard 플랜 카드가 존재하는지 확인
  test "B2B Standard 플랜 카드가 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-plan='b2b_standard']"
  end

  # PlanSelector: b2b_enterprise 플랜 카드가 존재하는지 확인
  test "B2B Enterprise 플랜 카드가 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-plan='b2b_enterprise']"
  end

  # PaymentMethod 컴포넌트: 결제 수단 섹션이 표시되는지 확인 (MVP에서는 UI만)
  test "결제 수단 섹션(PaymentMethod)이 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-component='payment-method']"
  end

  # BillingHistory 컴포넌트: 결제 이력 섹션이 표시되는지 확인
  test "결제 이력 섹션(BillingHistory)이 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-component='billing-history']"
  end

  # BillingHistory: 구독이 없을 때 빈 상태 메시지가 표시되는지 확인
  test "결제 이력이 없을 때 빈 상태 메시지가 표시된다" do
    get b2b_billing_path, headers: session_headers
    # MVP에서는 항상 빈 상태 (결제 이력 API 미구현)
    assert_select "[data-component='billing-history'] [data-component='empty-state']"
  end

  # 사이드바: B2B 대시보드 사이드바 네비게이션이 표시되는지 확인
  test "B2B 사이드바 네비게이션이 표시된다" do
    get b2b_billing_path, headers: session_headers
    assert_select "[data-nav='b2b-sidebar']"
  end

  # B2C 사용자는 B2B 결제 페이지에 접근할 수 없다
  test "B2C 사용자는 B2B 결제 페이지에 접근하면 리다이렉트된다" do
    b2c_user = User.create!(
      email: "b2c_billing_test@example.com",
      name: "일반 사용자",
      user_type: :b2c,
      is_active: true
    )
    b2c_session = b2c_user.sessions.create!

    get b2b_billing_path, headers: { "Cookie" => "b2b_session_token=#{b2c_session.token}" }
    assert_response :redirect
  ensure
    Session.where(user_id: b2c_user&.id).delete_all
    b2c_user&.destroy
  end

  private

  # B2B 세션 쿠키를 헤더로 변환하는 헬퍼
  def session_headers
    { "Cookie" => "b2b_session_token=#{@db_session.token}" }
  end
end
