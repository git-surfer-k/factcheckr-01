# frozen_string_literal: true

# @TASK P3-R1-T1 - Channels API 컨트롤러 테스트
# @TEST test/controllers/api/v1/channels_controller_test.rb
# GET /api/v1/channels, GET /api/v1/channels/:id
require "test_helper"

class Api::V1::ChannelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "channel_viewer@example.com",
      name: "채널 조회자",
      user_type: :b2c
    )
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }

    @channel = Channel.create!(
      youtube_channel_id: "UC_ranking_channel_001",
      name: "팩트체크 뉴스 채널",
      description: "시사/뉴스 전문 채널",
      subscriber_count: 500_000,
      category: "시사",
      trust_score: 85.5,
      total_checks: 25,
      thumbnail_url: "https://example.com/thumb1.jpg"
    )

    @channel2 = Channel.create!(
      youtube_channel_id: "UC_ranking_channel_002",
      name: "정치 토론 채널",
      description: "정치 이슈 분석",
      subscriber_count: 200_000,
      category: "정치",
      trust_score: 72.0,
      total_checks: 15,
      thumbnail_url: "https://example.com/thumb2.jpg"
    )

    @channel3 = Channel.create!(
      youtube_channel_id: "UC_ranking_channel_003",
      name: "시사 토론 채널",
      description: "시사 이슈 토론",
      subscriber_count: 300_000,
      category: "시사",
      trust_score: 92.0,
      total_checks: 30,
      thumbnail_url: "https://example.com/thumb3.jpg"
    )
  end

  # === GET /api/v1/channels ===

  test "index: 채널 목록을 반환한다" do
    get "/api/v1/channels",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert json.key?("channels")
    assert json.key?("meta")
    assert_equal 3, json["channels"].length
  end

  test "index: trust_score 내림차순으로 정렬된다" do
    get "/api/v1/channels",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    scores = json["channels"].map { |ch| ch["trust_score"].to_f }
    assert_equal scores.sort.reverse, scores
  end

  test "index: category 필터가 동작한다" do
    get "/api/v1/channels",
      params: { category: "시사" },
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json["channels"].length
    json["channels"].each do |ch|
      assert_equal "시사", ch["category"]
    end
  end

  test "index: 페이지네이션이 동작한다" do
    get "/api/v1/channels",
      params: { page: 1, per_page: 2 },
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json["channels"].length
    assert_equal 3, json["meta"]["total_count"]
    assert_equal 1, json["meta"]["current_page"]
    assert_equal 2, json["meta"]["total_pages"]

    # 두 번째 페이지
    get "/api/v1/channels",
      params: { page: 2, per_page: 2 },
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json["channels"].length
    assert_equal 2, json["meta"]["current_page"]
  end

  test "index: per_page 파라미터로 페이지 크기를 변경할 수 있다" do
    get "/api/v1/channels",
      params: { per_page: 1 },
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json["channels"].length
    assert_equal 1, json["meta"]["per_page"]
  end

  test "index: 인증 없이 요청하면 401 에러" do
    get "/api/v1/channels", as: :json

    assert_response :unauthorized
  end

  test "index: 응답에 필수 필드가 포함된다" do
    get "/api/v1/channels",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    channel = json["channels"].first
    expected_fields = %w[id youtube_channel_id name description subscriber_count
                         category trust_score total_checks thumbnail_url created_at]
    expected_fields.each do |field|
      assert channel.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  test "index: search 파라미터로 이름 검색이 동작한다" do
    get "/api/v1/channels",
      params: { search: "토론" },
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json["channels"].length
    json["channels"].each do |ch|
      assert ch["name"].include?("토론"), "채널 이름에 '토론'이 포함되어야 합니다"
    end
  end

  # === GET /api/v1/channels/:id ===

  test "show: 채널 상세 정보를 반환한다" do
    get "/api/v1/channels/#{@channel.id}",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @channel.id, json["id"]
    assert_equal "팩트체크 뉴스 채널", json["name"]
    assert_equal "시사", json["category"]
    assert_equal "85.5", json["trust_score"]
    assert_equal 500_000, json["subscriber_count"]
    assert_equal 25, json["total_checks"]
  end

  test "show: 존재하지 않는 ID로 조회하면 404 에러" do
    get "/api/v1/channels/nonexistent-uuid-value",
      headers: @auth_headers,
      as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "show: 인증 없이 요청하면 401 에러" do
    get "/api/v1/channels/#{@channel.id}", as: :json

    assert_response :unauthorized
  end

  test "show: 응답에 필수 필드가 포함된다" do
    get "/api/v1/channels/#{@channel.id}",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    expected_fields = %w[id youtube_channel_id name description subscriber_count
                         category trust_score total_checks thumbnail_url created_at]
    expected_fields.each do |field|
      assert json.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end
end
