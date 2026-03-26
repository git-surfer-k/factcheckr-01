# frozen_string_literal: true

# @TASK P4-S2-T1 - 설정 화면 UI 통합 테스트
# @SPEC specs/screens/b2c-settings.yaml
# 설정 페이지의 프로필 섹션, 구독 섹션, 로그아웃 기능을 검증
require "test_helper"

class SettingsPageTest < ActionDispatch::IntegrationTest
  # 로그인하지 않고 설정 페이지 접근 시 /auth로 리다이렉트
  test "비로그인 상태에서 설정 페이지 접근 시 로그인 페이지로 이동" do
    get settings_path
    assert_redirected_to "/auth"
  end

  # 로그인 상태에서 설정 페이지 정상 로드
  test "로그인 상태에서 설정 페이지가 정상 로드된다" do
    user = create_test_user
    log_in_as(user)

    get settings_path
    assert_response :success
  end

  # 프로필 섹션: 이메일 표시 확인
  test "프로필 섹션에 이메일이 표시된다" do
    user = create_test_user(email: "test@example.com")
    log_in_as(user)

    get settings_path
    assert_response :success
    assert_select "[data-component='profile-section']"
    assert_match "test@example.com", response.body
  end

  # 프로필 섹션: 이름 수정 폼 존재 확인
  test "이름 수정 폼이 표시된다" do
    user = create_test_user
    log_in_as(user)

    get settings_path
    assert_select "form[data-component='name-edit-form']"
    assert_select "input[name='name']"
  end

  # 구독 섹션: 구독 상태 카드 표시 확인
  test "구독 섹션이 표시된다" do
    user = create_test_user
    log_in_as(user)

    get settings_path
    assert_select "[data-component='subscription-section']"
  end

  # 구독 섹션: 활성 구독 정보 표시
  test "활성 구독이 있을 때 플랜 정보가 표시된다" do
    user = create_test_user
    # 활성 구독 생성
    Subscription.create!(
      user: user,
      plan_type: :b2c_basic,
      status: :active,
      started_at: Time.current,
      expires_at: 30.days.from_now
    )
    log_in_as(user)

    get settings_path
    assert_response :success
    assert_select "[data-component='subscription-section']"
  end

  # 구독 섹션: 구독이 없을 때 무료 플랜 표시
  test "활성 구독이 없을 때 무료 플랜 안내가 표시된다" do
    user = create_test_user
    log_in_as(user)

    get settings_path
    assert_response :success
    assert_match "무료", response.body
  end

  # 로그아웃 버튼 존재 확인
  test "로그아웃 버튼이 표시된다" do
    user = create_test_user
    log_in_as(user)

    get settings_path
    assert_select "[data-component='logout-button']"
  end

  # 로그아웃 API가 정상 응답을 반환하는지 확인 (X-Session-Token 헤더 사용)
  test "로그아웃 API가 정상 응답을 반환한다" do
    user = create_test_user
    web_session = user.sessions.create!

    # API 컨트롤러는 X-Session-Token 헤더로 인증
    delete "/api/v1/auth/logout", headers: { "X-Session-Token" => web_session.token }
    assert_response :success
  end

  private

  # 테스트용 사용자 생성 헬퍼
  def create_test_user(email: "settings_test@example.com")
    User.create!(
      email: email,
      user_type: :b2c,
      is_active: true
    )
  end

  # 세션 쿠키를 설정하여 로그인 상태를 시뮬레이션
  def log_in_as(user)
    web_session = user.sessions.create!
    cookies[:session_token] = web_session.token
  end
end
