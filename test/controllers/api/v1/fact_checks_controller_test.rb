# frozen_string_literal: true

# @TASK P2-R1-T1 - FactChecks API 컨트롤러 테스트
# @TEST test/controllers/api/v1/fact_checks_controller_test.rb
# POST /api/v1/fact_checks, GET /api/v1/fact_checks/:id, GET /api/v1/fact_checks
require "test_helper"

class Api::V1::FactChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "factchecker@example.com",
      name: "팩트체커",
      user_type: :b2c
    )
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }

    @channel = Channel.create!(
      youtube_channel_id: "UC_factcheck_channel_001",
      name: "팩트체크 테스트 채널"
    )

    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=existingVid",
      youtube_video_id: "existingVid",
      video_title: "기존 팩트체크 영상",
      status: :completed,
      overall_score: 75.5,
      completed_at: Time.current
    )
  end

  # === POST /api/v1/fact_checks ===

  test "create: 유효한 youtube_url로 팩트체크를 생성한다" do
    assert_difference("FactCheck.count", 1) do
      post "/api/v1/fact_checks",
        params: { youtube_url: "https://www.youtube.com/watch?v=newVideo123" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "pending", json["status"]
    assert_equal "newVideo123", json["youtube_video_id"]
    assert_not_nil json["id"]
    assert_not_nil json["created_at"]
  end

  test "create: youtube_url이 없으면 400 에러" do
    assert_no_difference("FactCheck.count") do
      post "/api/v1/fact_checks",
        params: {},
        headers: @auth_headers,
        as: :json
    end

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "create: 올바르지 않은 youtube_url이면 422 에러" do
    assert_no_difference("FactCheck.count") do
      post "/api/v1/fact_checks",
        params: { youtube_url: "https://www.google.com/watch?v=abc" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "create: 인증 없이 요청하면 401 에러" do
    post "/api/v1/fact_checks",
      params: { youtube_url: "https://www.youtube.com/watch?v=noAuth" },
      as: :json

    assert_response :unauthorized
  end

  test "create: youtu.be 단축 URL도 처리한다" do
    post "/api/v1/fact_checks",
      params: { youtube_url: "https://youtu.be/shortUrl123" },
      headers: @auth_headers,
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "shortUrl123", json["youtube_video_id"]
  end

  test "create: 응답에 필수 필드가 포함된다" do
    post "/api/v1/fact_checks",
      params: { youtube_url: "https://www.youtube.com/watch?v=fields123" },
      headers: @auth_headers,
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    expected_fields = %w[id user_id youtube_video_id youtube_url status created_at]
    expected_fields.each do |field|
      assert json.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  # === GET /api/v1/fact_checks/:id ===

  test "show: 팩트체크 상세 정보를 반환한다" do
    get "/api/v1/fact_checks/#{@fact_check.id}",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @fact_check.id, json["id"]
    assert_equal "completed", json["status"]
    assert_equal "75.5", json["overall_score"]
    assert_equal "기존 팩트체크 영상", json["video_title"]
  end

  test "show: 다른 사용자의 팩트체크는 조회할 수 없다" do
    other_user = User.create!(email: "other_fc@example.com", user_type: :b2c)
    other_fc = FactCheck.create!(
      user: other_user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=otherUser",
      youtube_video_id: "otherUser"
    )

    get "/api/v1/fact_checks/#{other_fc.id}",
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "show: 존재하지 않는 ID로 조회하면 404 에러" do
    get "/api/v1/fact_checks/nonexistent-uuid-value",
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "show: 인증 없이 요청하면 401 에러" do
    get "/api/v1/fact_checks/#{@fact_check.id}", as: :json

    assert_response :unauthorized
  end

  test "show: 응답에 분석 결과 필드가 포함된다" do
    get "/api/v1/fact_checks/#{@fact_check.id}",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    expected_fields = %w[id user_id channel_id youtube_video_id youtube_url
                         video_title status overall_score created_at completed_at]
    expected_fields.each do |field|
      assert json.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  # === GET /api/v1/fact_checks ===

  test "index: 현재 사용자의 팩트체크 목록을 반환한다" do
    get "/api/v1/fact_checks",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert json.key?("fact_checks")
    assert json.key?("meta")
    assert_equal 1, json["fact_checks"].length
  end

  test "index: 다른 사용자의 팩트체크는 포함하지 않는다" do
    other_user = User.create!(email: "another_fc@example.com", user_type: :b2c)
    FactCheck.create!(
      user: other_user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=anotherUser",
      youtube_video_id: "anotherUser"
    )

    get "/api/v1/fact_checks",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    # 다른 사용자의 팩트체크는 포함되지 않으므로 1개만
    assert_equal 1, json["fact_checks"].length
  end

  test "index: 최신 순으로 정렬된다" do
    older_fc = FactCheck.create!(
      user: @user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=olderVid",
      youtube_video_id: "olderVid",
      created_at: 3.days.ago
    )

    get "/api/v1/fact_checks",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    ids = json["fact_checks"].map { |fc| fc["id"] }
    assert_equal @fact_check.id, ids.first
  end

  test "index: 페이지네이션이 동작한다" do
    # 기존 1개 + 추가 10개 = 총 11개
    10.times do |i|
      FactCheck.create!(
        user: @user, channel: @channel,
        youtube_url: "https://youtube.com/watch?v=page#{i}",
        youtube_video_id: "page#{i}"
      )
    end

    # 첫 페이지 (기본 per_page=10)
    get "/api/v1/fact_checks", params: { page: 1 },
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 10, json["fact_checks"].length
    assert_equal 11, json["meta"]["total_count"]
    assert_equal 1, json["meta"]["current_page"]
    assert_equal 2, json["meta"]["total_pages"]

    # 두 번째 페이지
    get "/api/v1/fact_checks", params: { page: 2 },
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json["fact_checks"].length
    assert_equal 2, json["meta"]["current_page"]
  end

  test "index: per_page 파라미터로 페이지 크기를 변경할 수 있다" do
    5.times do |i|
      FactCheck.create!(
        user: @user, channel: @channel,
        youtube_url: "https://youtube.com/watch?v=perpage#{i}",
        youtube_video_id: "perpage#{i}"
      )
    end

    get "/api/v1/fact_checks", params: { per_page: 3 },
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 3, json["fact_checks"].length
  end

  test "index: 인증 없이 요청하면 401 에러" do
    get "/api/v1/fact_checks", as: :json

    assert_response :unauthorized
  end

  test "index: status 필터가 동작한다" do
    FactCheck.create!(
      user: @user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=pendingVid",
      youtube_video_id: "pendingVid",
      status: :pending
    )

    get "/api/v1/fact_checks", params: { status: "completed" },
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    json["fact_checks"].each do |fc|
      assert_equal "completed", fc["status"]
    end
  end
end
