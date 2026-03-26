# frozen_string_literal: true

# @TASK P5-S1-T1 - B2B 로그인 화면 통합 테스트
# @SPEC specs/screens/b2b-login.yaml (예정)
# B2B 로그인 페이지 렌더링, 폼 구성, 라우트를 검증한다.
require "test_helper"

class B2bLoginTest < ActionDispatch::IntegrationTest
  # 로그인 페이지가 200 응답을 반환하는지 확인
  test "B2B 로그인 페이지가 정상적으로 로드된다" do
    get b2b_login_path
    assert_response :success
  end

  # B2B 전용 레이아웃이 적용되는지 확인 (사이드바 없는 심플 레이아웃)
  test "B2B 전용 레이아웃이 적용된다" do
    get b2b_login_path
    assert_response :success
    # B2B 레이아웃 식별자 확인
    assert_select "[data-layout='b2b']"
  end

  # "Factis for Business" 브랜딩이 표시되는지 확인
  test "Factis for Business 브랜딩이 표시된다" do
    get b2b_login_path
    assert_select "[data-component='b2b-brand']"
    assert_match "Factis for Business", response.body
  end

  # 이메일 입력 폼이 존재하는지 확인
  test "이메일 입력 폼이 표시된다" do
    get b2b_login_path
    assert_select "form[data-component='b2b-auth-form']"
    assert_select "input[type='email'][name='email']"
  end

  # OTP 요청 버튼이 존재하는지 확인
  test "인증 코드 요청 버튼이 표시된다" do
    get b2b_login_path
    assert_select "button[data-action='request-otp']"
  end

  # B2B 로그인 라우트가 올바르게 매핑되는지 확인
  test "B2B 로그인 라우트가 올바르게 매핑된다" do
    assert_routing(
      { path: "/b2b/login", method: :get },
      { controller: "b2b/sessions", action: "new" }
    )
  end

  # POST 라우트가 존재하는지 확인 (OTP 요청)
  test "B2B OTP 요청 라우트가 올바르게 매핑된다" do
    assert_routing(
      { path: "/b2b/login", method: :post },
      { controller: "b2b/sessions", action: "create" }
    )
  end

  # 로그인 페이지에서는 사이드바 네비게이션이 표시되지 않아야 함
  test "로그인 페이지에는 사이드바가 표시되지 않는다" do
    get b2b_login_path
    assert_select "[data-nav='b2b-sidebar']", count: 0
  end

  # Trust Blue 색상 계열 CSS 클래스가 적용되는지 확인
  test "Trust Blue 테마가 적용된다" do
    get b2b_login_path
    assert_select "[data-theme='trust-blue']"
  end
end
