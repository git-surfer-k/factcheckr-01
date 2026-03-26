# frozen_string_literal: true

# @TASK ADMIN-T1 - 관리자 페이지 통합 테스트
# 관리자 인증, 대시보드, 사용자 관리, API 설정 테스트
require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  # ============================================================
  # 테스트 데이터 준비
  # ============================================================
  setup do
    # 기본 관리자 자격 증명
    @admin_email = ENV.fetch("ADMIN_EMAIL", "admin@factis.com")
    @admin_password = ENV.fetch("ADMIN_PASSWORD", "factis-admin-2026")

    # 테스트 사용자 생성
    @user = User.create!(
      email: "test-admin-user@example.com",
      name: "테스트사용자",
      user_type: :b2c,
      is_active: true
    )

    # 테스트 채널 생성
    @channel = Channel.create!(
      youtube_channel_id: "UC_admin_test_channel",
      name: "관리자테스트채널",
      category: "정치",
      trust_score: 75.0
    )

    # 테스트 팩트체크 생성
    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=admin_test_123",
      status: :completed
    )
  end

  teardown do
    # 테스트 데이터 정리
    AdminSetting.where(key: "test_key").destroy_all
  end

  # ============================================================
  # 관리자 인증 테스트
  # ============================================================

  # 비로그인 시 관리자 대시보드 접근 불가 (로그인 페이지로 리다이렉트)
  test "관리자 대시보드 접근 시 로그인 필요" do
    get "/admin"
    assert_redirected_to "/admin/login"
    follow_redirect!
    assert_response :success
  end

  # 로그인 페이지 정상 렌더링
  test "관리자 로그인 페이지 렌더링" do
    get "/admin/login"
    assert_response :success
    assert_select "input[name='email']"
    assert_select "input[name='password']"
    assert_select "button[type='submit']"
  end

  # 올바른 자격 증명으로 로그인 성공
  test "관리자 로그인 성공" do
    post "/admin/login", params: { email: @admin_email, password: @admin_password }
    assert_redirected_to "/admin"
    follow_redirect!
    assert_response :success
  end

  # 잘못된 자격 증명으로 로그인 실패
  test "관리자 로그인 실패 - 잘못된 비밀번호" do
    post "/admin/login", params: { email: @admin_email, password: "wrong-password" }
    assert_response :unprocessable_entity
  end

  test "관리자 로그인 실패 - 잘못된 이메일" do
    post "/admin/login", params: { email: "wrong@factis.com", password: @admin_password }
    assert_response :unprocessable_entity
  end

  # 로그아웃 테스트
  test "관리자 로그아웃" do
    admin_login!
    delete "/admin/logout"
    assert_redirected_to "/admin/login"

    # 로그아웃 후 대시보드 접근 불가
    get "/admin"
    assert_redirected_to "/admin/login"
  end

  # 이미 로그인된 관리자가 로그인 페이지 접근 시 대시보드로 리다이렉트
  test "이미 로그인된 관리자 로그인 페이지 리다이렉트" do
    admin_login!
    get "/admin/login"
    assert_redirected_to "/admin"
  end

  # ============================================================
  # 대시보드 테스트
  # ============================================================

  # 대시보드 정상 렌더링 (통계, 최근 사용자, 최근 팩트체크)
  test "관리자 대시보드 표시" do
    admin_login!
    get "/admin"
    assert_response :success
    # 통계 카드 존재 확인
    assert_select "p", /#{User.count}/
    assert_select "p", /#{FactCheck.count}/
    assert_select "p", /#{Channel.count}/
  end

  # ============================================================
  # 사용자 관리 테스트
  # ============================================================

  # 사용자 목록 페이지 렌더링
  test "관리자 사용자 목록 표시" do
    admin_login!
    get "/admin/users"
    assert_response :success
    assert_select "table"
    assert_select "a", text: @user.email
  end

  # 사용자 상세 페이지 렌더링
  test "관리자 사용자 상세 표시" do
    admin_login!
    get "/admin/users/#{@user.id}"
    assert_response :success
    assert_select "p", text: @user.email
  end

  # 사용자 비활성화 토글
  test "관리자 사용자 비활성화" do
    admin_login!
    assert @user.is_active

    patch "/admin/users/#{@user.id}/toggle_active"
    assert_redirected_to "/admin/users/#{@user.id}"

    @user.reload
    assert_not @user.is_active
  end

  # 사용자 활성화 토글
  test "관리자 사용자 활성화" do
    @user.update!(is_active: false)
    admin_login!

    patch "/admin/users/#{@user.id}/toggle_active"
    assert_redirected_to "/admin/users/#{@user.id}"

    @user.reload
    assert @user.is_active
  end

  # 페이지네이션 (page 파라미터 동작)
  test "관리자 사용자 목록 페이지네이션" do
    admin_login!
    get "/admin/users", params: { page: 1 }
    assert_response :success
  end

  # ============================================================
  # API 설정 테스트
  # ============================================================

  # 설정 페이지 렌더링
  test "관리자 설정 페이지 표시" do
    admin_login!
    get "/admin/settings"
    assert_response :success
    # 설정 섹션 존재 확인
    assert_select "h2", text: "AI 모델 설정"
    assert_select "h2", text: "빅카인즈 API"
    assert_select "h2", text: /이메일 설정/
    assert_select "h2", text: "시스템 상태"
  end

  # 설정 업데이트
  test "관리자 설정 업데이트" do
    admin_login!
    patch "/admin/settings", params: {
      settings: {
        openai_model: "gpt-4o-mini",
        resend_from_email: "Test <test@factis.com>"
      }
    }
    assert_redirected_to "/admin/settings"

    assert_equal "gpt-4o-mini", AdminSetting.get("openai_model")
    assert_equal "Test <test@factis.com>", AdminSetting.get("resend_from_email")
  end

  # 마스킹된 값은 업데이트하지 않음
  test "관리자 설정 마스킹된 API 키는 변경 안 함" do
    AdminSetting.set("openai_api_key", "sk-real-key-12345678")
    admin_login!

    patch "/admin/settings", params: {
      settings: {
        openai_api_key: "sk-r****************"
      }
    }

    # 마스킹된 값이므로 원본 유지
    assert_equal "sk-real-key-12345678", AdminSetting.get("openai_api_key")
  end

  # 허용되지 않은 키는 무시
  test "관리자 설정 허용되지 않은 키 무시" do
    admin_login!
    patch "/admin/settings", params: {
      settings: {
        malicious_key: "bad_value"
      }
    }
    assert_nil AdminSetting.find_by(key: "malicious_key")
  end

  # ============================================================
  # AdminSetting 모델 테스트
  # ============================================================

  test "AdminSetting.get - DB값 우선 반환" do
    AdminSetting.create!(key: "test_key", value: "db_value")
    assert_equal "db_value", AdminSetting.get("test_key", "default")
  end

  test "AdminSetting.get - DB값 없으면 기본값 반환" do
    assert_equal "fallback", AdminSetting.get("nonexistent_key", "fallback")
  end

  test "AdminSetting.set - 생성 및 갱신" do
    AdminSetting.set("test_key", "value1")
    assert_equal "value1", AdminSetting.get("test_key")

    AdminSetting.set("test_key", "value2")
    assert_equal "value2", AdminSetting.get("test_key")
    assert_equal 1, AdminSetting.where(key: "test_key").count
  end

  test "AdminSetting masked_value - 4자 초과 마스킹" do
    setting = AdminSetting.new(key: "test", value: "sk-abc123456")
    # 처음 4자(sk-a) + 나머지 8자(bc123456)를 * 처리
    assert_equal "sk-a" + ("*" * 8), setting.masked_value
  end

  test "AdminSetting masked_value - 4자 이하 마스킹 안 함" do
    setting = AdminSetting.new(key: "test", value: "sk")
    assert_equal "sk", setting.masked_value
  end

  test "AdminSetting masked_value - 빈 값" do
    setting = AdminSetting.new(key: "test", value: "")
    assert_equal "", setting.masked_value
  end

  # ============================================================
  # 인증 없이 관리자 페이지 접근 차단 테스트
  # ============================================================

  test "비인증 사용자 관리 접근 차단" do
    get "/admin/users"
    assert_redirected_to "/admin/login"
  end

  test "비인증 설정 접근 차단" do
    get "/admin/settings"
    assert_redirected_to "/admin/login"
  end

  test "비인증 사용자 토글 차단" do
    patch "/admin/users/#{@user.id}/toggle_active"
    assert_redirected_to "/admin/login"
  end

  private

  # 관리자 로그인 헬퍼
  def admin_login!
    post "/admin/login", params: {
      email: @admin_email,
      password: @admin_password
    }
    assert_redirected_to "/admin"
  end
end
