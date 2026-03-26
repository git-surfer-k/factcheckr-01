# frozen_string_literal: true

# @TASK P2-R2-T1 - Claims 컨트롤러 테스트
# @TEST test/controllers/api/v1/claims_controller_test.rb
require "test_helper"

class Api::V1::ClaimsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "claims-api@example.com", user_type: :b2c)
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }

    @channel = Channel.create!(youtube_channel_id: "UC_claims_api", name: "Claims API Channel")
    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=claims_test1",
      status: :completed
    )

    @claim1 = Claim.create!(
      fact_check: @fact_check,
      claim_text: "첫 번째 주장입니다.",
      verdict: :true_claim,
      confidence: 0.95,
      explanation: "뉴스 기사 근거가 충분합니다.",
      timestamp_start: 10,
      timestamp_end: 30
    )

    @claim2 = Claim.create!(
      fact_check: @fact_check,
      claim_text: "두 번째 주장입니다.",
      verdict: :false_claim,
      confidence: 0.80,
      explanation: "근거 자료와 일치하지 않습니다.",
      timestamp_start: 60,
      timestamp_end: 90
    )
  end

  # ===========================================
  # GET /api/v1/fact_checks/:fact_check_id/claims
  # ===========================================

  test "index: 팩트체크의 주장 목록을 반환한다" do
    get "/api/v1/fact_checks/#{@fact_check.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal 2, json["claims"].length

    first_claim = json["claims"].first
    assert_not_nil first_claim["id"]
    assert_not_nil first_claim["fact_check_id"]
    assert_not_nil first_claim["claim_text"]
    assert_not_nil first_claim["verdict"]
    assert_not_nil first_claim["confidence"]
    assert_not_nil first_claim["explanation"]
    assert_not_nil first_claim["timestamp_start"]
    assert_not_nil first_claim["timestamp_end"]
  end

  test "index: 응답에 embedding 필드가 포함되지 않는다" do
    get "/api/v1/fact_checks/#{@fact_check.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    json["claims"].each do |claim|
      assert_not claim.key?("embedding"), "embedding 필드가 API 응답에 포함되면 안 됩니다"
    end
  end

  test "index: 주장이 timestamp_start 오름차순으로 정렬된다" do
    get "/api/v1/fact_checks/#{@fact_check.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    claims = json["claims"]
    assert_equal @claim1.id, claims.first["id"]
    assert_equal @claim2.id, claims.last["id"]
  end

  test "index: 다른 fact_check 의 주장은 포함되지 않는다" do
    other_fc = FactCheck.create!(user: @user, channel: @channel, youtube_url: "https://www.youtube.com/watch?v=other_fc_1", status: :completed)
    Claim.create!(
      fact_check: other_fc,
      claim_text: "다른 팩트체크의 주장",
      verdict: :unverified
    )

    get "/api/v1/fact_checks/#{@fact_check.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json["claims"].length
  end

  test "index: 주장이 없으면 빈 배열을 반환한다" do
    empty_fc = FactCheck.create!(user: @user, channel: @channel, youtube_url: "https://www.youtube.com/watch?v=empty_fc_1", status: :pending)

    get "/api/v1/fact_checks/#{empty_fc.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal [], json["claims"]
  end

  # ===========================================
  # 인증 관련 테스트
  # ===========================================

  test "index: 인증 없이 요청하면 401 에러" do
    get "/api/v1/fact_checks/#{@fact_check.id}/claims", as: :json

    assert_response :unauthorized
  end

  # ===========================================
  # 권한 검증 테스트 (다른 유저의 fact_check)
  # ===========================================

  test "index: 다른 유저의 fact_check 에 접근하면 404 에러" do
    other_user = User.create!(email: "other-claims@example.com", user_type: :b2c)
    other_fc = FactCheck.create!(user: other_user, channel: @channel, youtube_url: "https://www.youtube.com/watch?v=other_user1", status: :completed)
    Claim.create!(fact_check: other_fc, claim_text: "다른 유저 주장", verdict: :true_claim)

    get "/api/v1/fact_checks/#{other_fc.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["detail"], "팩트체크"
  end

  test "index: 존재하지 않는 fact_check_id 로 요청하면 404 에러" do
    get "/api/v1/fact_checks/nonexistent-uuid/claims",
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  # ===========================================
  # 응답 필드 상세 테스트
  # ===========================================

  test "index: 각 claim 의 verdict 가 문자열로 반환된다" do
    get "/api/v1/fact_checks/#{@fact_check.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    verdicts = json["claims"].map { |c| c["verdict"] }
    assert_includes verdicts, "true_claim"
    assert_includes verdicts, "false_claim"
  end

  test "index: confidence 가 숫자로 반환된다" do
    get "/api/v1/fact_checks/#{@fact_check.id}/claims",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    json["claims"].each do |claim|
      assert_kind_of Numeric, claim["confidence"].to_f
    end
  end
end
