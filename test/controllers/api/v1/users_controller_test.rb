# frozen_string_literal: true

# @TASK P1-R1-T1 - Users API 컨트롤러 테스트
# @TEST test/controllers/api/v1/users_controller_test.rb
# GET /api/v1/users/me, PATCH /api/v1/users/me, DELETE /api/v1/users/me
require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "testuser@example.com",
      name: "테스트유저",
      user_type: :b2c
    )
    # OTP 인증 후 세션 생성
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }
  end

  # --- GET /api/v1/users/me ---

  test "me: 인증된 사용자 정보를 반환한다" do
    get "/api/v1/users/me", headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @user.id, json["id"]
    assert_equal "testuser@example.com", json["email"]
    assert_equal "b2c", json["user_type"]
    assert_equal "테스트유저", json["name"]
    assert_not_nil json["created_at"]
  end

  test "me: 필수 필드(id, email, name, user_type, created_at)가 모두 포함된다" do
    get "/api/v1/users/me", headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    expected_fields = %w[id email name user_type created_at]
    expected_fields.each do |field|
      assert json.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  test "me: 인증 없이 요청하면 401 에러" do
    get "/api/v1/users/me", as: :json

    assert_response :unauthorized
  end

  test "me: b2b 사용자의 user_type이 올바르게 반환된다" do
    b2b_user = User.create!(email: "b2b@example.com", user_type: :b2b)
    b2b_session = b2b_user.create_session!

    get "/api/v1/users/me", headers: { "X-Session-Token" => b2b_session.token }, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "b2b", json["user_type"]
  end

  # --- PATCH /api/v1/users/me ---

  test "update_me: name 필드를 업데이트할 수 있다" do
    patch "/api/v1/users/me", params: { name: "새이름" }, headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "새이름", json["name"]

    # DB에도 반영 확인
    @user.reload
    assert_equal "새이름", @user.name
  end

  test "update_me: 응답에 user_type이 포함된다" do
    patch "/api/v1/users/me", params: { name: "업데이트" }, headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "b2c", json["user_type"]
  end

  test "update_me: name을 빈 문자열로 업데이트할 수 있다" do
    patch "/api/v1/users/me", params: { name: "" }, headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "", json["name"]
  end

  test "update_me: email은 변경할 수 없다 (허용되지 않는 파라미터)" do
    original_email = @user.email

    patch "/api/v1/users/me", params: { email: "hacked@example.com" }, headers: @auth_headers, as: :json

    assert_response :ok
    @user.reload
    assert_equal original_email, @user.email
  end

  test "update_me: user_type은 변경할 수 없다 (허용되지 않는 파라미터)" do
    patch "/api/v1/users/me", params: { user_type: "b2b" }, headers: @auth_headers, as: :json

    assert_response :ok
    @user.reload
    assert_equal "b2c", @user.user_type
  end

  test "update_me: 인증 없이 요청하면 401 에러" do
    patch "/api/v1/users/me", params: { name: "해킹" }, as: :json

    assert_response :unauthorized
  end

  test "update_me: PUT 메서드로도 업데이트할 수 있다" do
    put "/api/v1/users/me", params: { name: "PUT이름" }, headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "PUT이름", json["name"]
  end

  # --- DELETE /api/v1/users/me ---

  test "destroy_me: 계정을 비활성화한다 (소프트 삭제)" do
    delete "/api/v1/users/me", headers: @auth_headers, as: :json

    assert_response :no_content

    @user.reload
    assert_not @user.is_active
  end

  test "destroy_me: 비활성화 후 다시 인증할 수 없다" do
    delete "/api/v1/users/me", headers: @auth_headers, as: :json
    assert_response :no_content

    # 같은 세션으로 재요청
    get "/api/v1/users/me", headers: @auth_headers, as: :json
    assert_response :unauthorized
  end

  test "destroy_me: 인증 없이 요청하면 401 에러" do
    delete "/api/v1/users/me", as: :json

    assert_response :unauthorized
  end
end
