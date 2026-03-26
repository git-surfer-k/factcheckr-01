# frozen_string_literal: true

# @TASK P1-R2-T1 - Subscriptions 컨트롤러 테스트
# @TEST test/controllers/api/v1/subscriptions_controller_test.rb
require "test_helper"

class Api::V1::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "subscriber@example.com", user_type: :b2c)
    # 세션 토큰을 생성해서 인증에 사용
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }

    @subscription = Subscription.create!(
      user: @user,
      plan_type: :b2c_basic,
      status: :active,
      started_at: Time.current,
      expires_at: 30.days.from_now,
      payment_method: "credit_card"
    )
  end

  # ===========================================
  # GET /api/v1/subscriptions/current
  # ===========================================

  test "current: 현재 활성 구독을 조회한다" do
    get "/api/v1/subscriptions/current", headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @subscription.id, json["id"]
    assert_equal "b2c_basic", json["plan_type"]
    assert_equal "active", json["status"]
    assert_not_nil json["started_at"]
    assert_not_nil json["expires_at"]
  end

  test "current: 활성 구독이 없으면 404를 반환한다" do
    @subscription.update!(status: :canceled)

    get "/api/v1/subscriptions/current", headers: @auth_headers, as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["detail"], "활성 구독"
  end

  test "current: 인증 없이 요청하면 401 에러" do
    get "/api/v1/subscriptions/current", as: :json

    assert_response :unauthorized
  end

  # ===========================================
  # POST /api/v1/subscriptions
  # ===========================================

  test "create: 새 구독을 생성한다" do
    # 기존 구독을 취소하고 새로 생성
    @subscription.update!(status: :canceled)

    assert_difference "Subscription.count", 1 do
      post "/api/v1/subscriptions",
        headers: @auth_headers,
        params: { plan_type: "b2c_premium" },
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "b2c_premium", json["plan_type"]
    assert_equal "active", json["status"]
    assert_not_nil json["started_at"]
    assert_not_nil json["expires_at"]
  end

  test "create: 이미 활성 구독이 있으면 409 충돌 에러" do
    post "/api/v1/subscriptions",
      headers: @auth_headers,
      params: { plan_type: "b2c_premium" },
      as: :json

    assert_response :conflict
    json = JSON.parse(response.body)
    assert_includes json["detail"], "이미 활성"
  end

  test "create: plan_type이 없으면 400 에러" do
    @subscription.update!(status: :canceled)

    post "/api/v1/subscriptions",
      headers: @auth_headers,
      params: {},
      as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_includes json["detail"], "plan_type"
  end

  test "create: 잘못된 plan_type이면 400 에러" do
    @subscription.update!(status: :canceled)

    post "/api/v1/subscriptions",
      headers: @auth_headers,
      params: { plan_type: "invalid_plan" },
      as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_includes json["detail"], "plan_type"
  end

  test "create: payment_method를 함께 저장한다" do
    @subscription.update!(status: :canceled)

    post "/api/v1/subscriptions",
      headers: @auth_headers,
      params: { plan_type: "b2c_basic", payment_method: "bank_transfer" },
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "bank_transfer", json["payment_method"]
  end

  test "create: 인증 없이 요청하면 401 에러" do
    post "/api/v1/subscriptions",
      params: { plan_type: "b2c_basic" },
      as: :json

    assert_response :unauthorized
  end

  # ===========================================
  # PUT /api/v1/subscriptions/:id
  # ===========================================

  test "update: 구독 플랜을 변경한다" do
    put "/api/v1/subscriptions/#{@subscription.id}",
      headers: @auth_headers,
      params: { plan_type: "b2c_premium" },
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "b2c_premium", json["plan_type"]

    @subscription.reload
    assert @subscription.b2c_premium?
  end

  test "update: payment_method를 변경한다" do
    put "/api/v1/subscriptions/#{@subscription.id}",
      headers: @auth_headers,
      params: { payment_method: "bank_transfer" },
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "bank_transfer", json["payment_method"]
  end

  test "update: 잘못된 plan_type이면 400 에러" do
    put "/api/v1/subscriptions/#{@subscription.id}",
      headers: @auth_headers,
      params: { plan_type: "invalid_plan" },
      as: :json

    assert_response :bad_request
  end

  test "update: 다른 사용자의 구독은 변경할 수 없다 (404)" do
    other_user = User.create!(email: "other@example.com", user_type: :b2c)
    other_sub = Subscription.create!(
      user: other_user,
      plan_type: :b2c_basic,
      status: :active,
      started_at: Time.current
    )

    put "/api/v1/subscriptions/#{other_sub.id}",
      headers: @auth_headers,
      params: { plan_type: "b2c_premium" },
      as: :json

    assert_response :not_found
  end

  test "update: 취소된 구독은 변경할 수 없다" do
    @subscription.update!(status: :canceled)

    put "/api/v1/subscriptions/#{@subscription.id}",
      headers: @auth_headers,
      params: { plan_type: "b2c_premium" },
      as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["detail"], "활성 구독"
  end

  test "update: 인증 없이 요청하면 401 에러" do
    put "/api/v1/subscriptions/#{@subscription.id}",
      params: { plan_type: "b2c_premium" },
      as: :json

    assert_response :unauthorized
  end

  # ===========================================
  # DELETE /api/v1/subscriptions/:id
  # ===========================================

  test "destroy: 구독을 취소한다 (status를 canceled로)" do
    delete "/api/v1/subscriptions/#{@subscription.id}",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "canceled", json["status"]
    assert_includes json["message"], "취소"

    @subscription.reload
    assert @subscription.canceled?
  end

  test "destroy: 이미 취소된 구독을 다시 취소하면 에러" do
    @subscription.update!(status: :canceled)

    delete "/api/v1/subscriptions/#{@subscription.id}",
      headers: @auth_headers,
      as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["detail"], "이미 취소"
  end

  test "destroy: 다른 사용자의 구독은 취소할 수 없다 (404)" do
    other_user = User.create!(email: "other@example.com", user_type: :b2c)
    other_sub = Subscription.create!(
      user: other_user,
      plan_type: :b2c_basic,
      status: :active,
      started_at: Time.current
    )

    delete "/api/v1/subscriptions/#{other_sub.id}",
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "destroy: 인증 없이 요청하면 401 에러" do
    delete "/api/v1/subscriptions/#{@subscription.id}",
      as: :json

    assert_response :unauthorized
  end
end
