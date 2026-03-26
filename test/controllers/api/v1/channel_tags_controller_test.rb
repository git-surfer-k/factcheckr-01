# frozen_string_literal: true

# @TASK P3-R3-T1 - ChannelTags API 컨트롤러 테스트
# @TEST test/controllers/api/v1/channel_tags_controller_test.rb
require "test_helper"

class Api::V1::ChannelTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "channel-tags-api@example.com", user_type: :b2c)
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }

    @channel = Channel.create!(youtube_channel_id: "UC_channel_tags_api", name: "Channel Tags Test")
  end

  # ===========================================
  # GET /api/v1/channels/:channel_id/tags
  # ===========================================

  test "index: 채널의 태그 목록을 반환한다" do
    ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)
    ChannelTag.create!(channel: @channel, tag_name: "경제", created_by: @user.id)

    get "/api/v1/channels/#{@channel.id}/tags",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    assert json.key?("tags")
    assert_equal 2, json["tags"].length
  end

  test "index: 응답에 필수 필드가 포함된다" do
    ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)

    get "/api/v1/channels/#{@channel.id}/tags",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    tag = json["tags"].first
    %w[id channel_id tag_name created_by].each do |field|
      assert tag.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  test "index: 다른 채널의 태그는 포함되지 않는다" do
    other_channel = Channel.create!(youtube_channel_id: "UC_other_tags", name: "Other Tags Channel")
    ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)
    ChannelTag.create!(channel: other_channel, tag_name: "스포츠", created_by: @user.id)

    get "/api/v1/channels/#{@channel.id}/tags",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json["tags"].length
    assert_equal "정치", json["tags"].first["tag_name"]
  end

  test "index: 태그가 없으면 빈 배열을 반환한다" do
    get "/api/v1/channels/#{@channel.id}/tags",
      headers: @auth_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal [], json["tags"]
  end

  test "index: 존재하지 않는 채널이면 404 에러" do
    get "/api/v1/channels/nonexistent-uuid/tags",
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "index: 인증 없이 요청하면 401 에러" do
    get "/api/v1/channels/#{@channel.id}/tags", as: :json

    assert_response :unauthorized
  end

  # ===========================================
  # POST /api/v1/channels/:channel_id/tags
  # ===========================================

  test "create: 유효한 tag_name 으로 태그를 생성한다" do
    assert_difference("ChannelTag.count", 1) do
      post "/api/v1/channels/#{@channel.id}/tags",
        params: { tag_name: "정치" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "정치", json["tag_name"]
    assert_equal @channel.id, json["channel_id"]
    assert_equal @user.id, json["created_by"]
  end

  test "create: created_by 가 현재 사용자 ID로 자동 설정된다" do
    post "/api/v1/channels/#{@channel.id}/tags",
      params: { tag_name: "경제" },
      headers: @auth_headers,
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal @user.id, json["created_by"]

    tag = ChannelTag.find(json["id"])
    assert_equal @user.id, tag.created_by
  end

  test "create: tag_name 이 없으면 422 에러" do
    assert_no_difference("ChannelTag.count") do
      post "/api/v1/channels/#{@channel.id}/tags",
        params: { tag_name: "" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "create: tag_name 파라미터 자체가 없으면 422 에러" do
    assert_no_difference("ChannelTag.count") do
      post "/api/v1/channels/#{@channel.id}/tags",
        params: {},
        headers: @auth_headers,
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create: 같은 채널에 중복 tag_name 이면 422 에러" do
    ChannelTag.create!(channel: @channel, tag_name: "정치", created_by: @user.id)

    assert_no_difference("ChannelTag.count") do
      post "/api/v1/channels/#{@channel.id}/tags",
        params: { tag_name: "정치" },
        headers: @auth_headers,
        as: :json
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "create: 존재하지 않는 채널이면 404 에러" do
    post "/api/v1/channels/nonexistent-uuid/tags",
      params: { tag_name: "정치" },
      headers: @auth_headers,
      as: :json

    assert_response :not_found
  end

  test "create: 인증 없이 요청하면 401 에러" do
    post "/api/v1/channels/#{@channel.id}/tags",
      params: { tag_name: "정치" },
      as: :json

    assert_response :unauthorized
  end

  test "create: 응답에 필수 필드가 포함된다" do
    post "/api/v1/channels/#{@channel.id}/tags",
      params: { tag_name: "IT/과학" },
      headers: @auth_headers,
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    %w[id channel_id tag_name created_by].each do |field|
      assert json.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end
end
