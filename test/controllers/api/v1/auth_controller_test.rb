# frozen_string_literal: true

# @TASK P0-T0.4 - Auth 컨트롤러 OTP 인증 테스트
# @TEST tests/controllers/api/v1/auth_controller_test.rb
require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @existing_user = User.create!(
      email: "existing@example.com",
      user_type: :b2c
    )
  end

  # --- POST /api/v1/auth/request_otp ---

  test "request_otp: 기존 사용자에게 OTP 발송 성공" do
    assert_enqueued_emails 1 do
      post "/api/v1/auth/request_otp", params: { email: "existing@example.com" }, as: :json
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_includes json["message"], "인증 코드"
    assert_equal "existing@example.com", json["email"]

    # DB에 OTP 코드가 저장되어 있는지 확인
    @existing_user.reload
    assert_not_nil @existing_user.otp_code
    assert_not_nil @existing_user.otp_sent_at
  end

  test "request_otp: 신규 이메일이면 사용자를 자동 생성하고 OTP 발송" do
    assert_difference "User.count", 1 do
      post "/api/v1/auth/request_otp", params: { email: "newuser@example.com" }, as: :json
    end

    assert_response :ok

    new_user = User.find_by(email: "newuser@example.com")
    assert_not_nil new_user
    assert_equal "b2c", new_user.user_type
    assert_not_nil new_user.otp_code
  end

  test "request_otp: 이메일이 비어 있으면 400 에러" do
    post "/api/v1/auth/request_otp", params: { email: "" }, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_includes json["detail"], "올바른 이메일"
  end

  test "request_otp: 잘못된 이메일 형식이면 400 에러" do
    post "/api/v1/auth/request_otp", params: { email: "not-an-email" }, as: :json

    assert_response :bad_request
  end

  test "request_otp: 비활성 사용자면 403 에러" do
    @existing_user.update!(is_active: false)

    post "/api/v1/auth/request_otp", params: { email: "existing@example.com" }, as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_includes json["detail"], "비활성화"
  end

  test "request_otp: 이메일 대소문자 구분 없이 동작" do
    post "/api/v1/auth/request_otp", params: { email: "EXISTING@EXAMPLE.COM" }, as: :json

    assert_response :ok
    # 기존 사용자의 OTP가 생성되어야 함 (새 사용자 생성 아님)
    assert_equal 1, User.where(email: "existing@example.com").count
  end

  # --- POST /api/v1/auth/verify_otp ---

  test "verify_otp: 올바른 OTP로 로그인 성공" do
    otp = @existing_user.generate_otp!

    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_not_nil json["session_token"]
    assert_equal @existing_user.id, json["user"]["id"]
    assert_includes json["message"], "로그인 성공"
  end

  test "verify_otp: 응답에 user_type이 포함된다" do
    otp = @existing_user.generate_otp!

    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "b2c", json["user"]["user_type"]
  end

  test "verify_otp: 세션이 생성된다" do
    otp = @existing_user.generate_otp!

    assert_difference "Session.count", 1 do
      post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json
    end

    assert_response :ok
  end

  test "verify_otp: 잘못된 OTP로 401 에러" do
    @existing_user.generate_otp!

    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: "000000" }, as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_includes json["detail"], "인증 코드"
  end

  test "verify_otp: 만료된 OTP로 401 에러" do
    otp = @existing_user.generate_otp!

    travel 6.minutes do
      post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json
    end

    assert_response :unauthorized
  end

  test "verify_otp: 존재하지 않는 이메일로 401 에러" do
    post "/api/v1/auth/verify_otp", params: { email: "nonexistent@example.com", otp_code: "123456" }, as: :json

    assert_response :unauthorized
  end

  test "verify_otp: 이메일이 비어 있으면 400 에러" do
    post "/api/v1/auth/verify_otp", params: { email: "", otp_code: "123456" }, as: :json

    assert_response :bad_request
  end

  test "verify_otp: OTP 코드가 비어 있으면 400 에러" do
    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: "" }, as: :json

    assert_response :bad_request
  end

  test "verify_otp: 비활성 사용자면 403 에러" do
    otp = @existing_user.generate_otp!
    @existing_user.update!(is_active: false)

    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json

    assert_response :forbidden
  end

  test "verify_otp: 같은 OTP로 두 번 로그인 불가 (재사용 방지)" do
    otp = @existing_user.generate_otp!

    # 첫 번째 시도: 성공
    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json
    assert_response :ok

    # 두 번째 시도: 실패
    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json
    assert_response :unauthorized
  end

  # --- DELETE /api/v1/auth/logout ---

  test "logout: 세션 삭제 성공" do
    otp = @existing_user.generate_otp!
    post "/api/v1/auth/verify_otp", params: { email: "existing@example.com", otp_code: otp }, as: :json
    session_token = JSON.parse(response.body)["session_token"]

    assert_difference "Session.count", -1 do
      delete "/api/v1/auth/logout", headers: { "X-Session-Token" => session_token }, as: :json
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_includes json["message"], "로그아웃"
  end

  test "logout: 인증 없이 요청하면 401 에러" do
    delete "/api/v1/auth/logout", as: :json

    assert_response :unauthorized
  end
end
