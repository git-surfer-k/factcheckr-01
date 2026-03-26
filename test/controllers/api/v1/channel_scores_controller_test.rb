# frozen_string_literal: true

# @TASK P3-R2-T1 - ChannelScores API 컨트롤러 테스트
# @TEST test/controllers/api/v1/channel_scores_controller_test.rb
# GET /api/v1/channels/:channel_id/scores 엔드포인트 검증
require "test_helper"

class Api::V1::ChannelScoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "scorer@example.com",
      name: "점수 테스터",
      user_type: :b2c
    )
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }

    @channel = Channel.create!(
      youtube_channel_id: "UC_score_api_001",
      name: "점수 API 테스트 채널"
    )

    # 테스트용 점수 이력 데이터 (시간순)
    @score_old = ChannelScore.create!(
      channel: @channel,
      score: 70.0,
      accuracy_rate: 65.0,
      source_citation_rate: 72.0,
      consistency_score: 68.0,
      recorded_at: 30.days.ago
    )

    @score_mid = ChannelScore.create!(
      channel: @channel,
      score: 78.5,
      accuracy_rate: 75.0,
      source_citation_rate: 80.0,
      consistency_score: 76.0,
      recorded_at: 15.days.ago
    )

    @score_new = ChannelScore.create!(
      channel: @channel,
      score: 85.0,
      accuracy_rate: 82.0,
      source_citation_rate: 88.0,
      consistency_score: 84.0,
      recorded_at: 1.day.ago
    )
  end

  # === GET /api/v1/channels/:channel_id/scores ===

  test "index: 채널의 점수 이력을 반환한다" do
    get "/api/v1/channels/#{@channel.id}/scores",
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert json.key?("scores")
    assert_equal 3, json["scores"].length
  end

  test "index: recorded_at 오름차순으로 정렬된다 (추이 그래프용)" do
    get "/api/v1/channels/#{@channel.id}/scores",
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    recorded_dates = json["scores"].map { |s| s["recorded_at"] }
    assert_equal recorded_dates, recorded_dates.sort
  end

  test "index: 응답에 필수 필드가 모두 포함된다" do
    get "/api/v1/channels/#{@channel.id}/scores",
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    score = json["scores"].first

    expected_fields = %w[id channel_id score accuracy_rate
                         source_citation_rate consistency_score recorded_at]
    expected_fields.each do |field|
      assert score.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  test "index: 존재하지 않는 channel_id로 요청하면 404를 반환한다" do
    get "/api/v1/channels/nonexistent-uuid/scores",
      headers: @auth_headers, as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "index: 인증 없이 요청하면 401 에러" do
    get "/api/v1/channels/#{@channel.id}/scores", as: :json

    assert_response :unauthorized
  end

  test "index: 점수 이력이 없으면 빈 배열을 반환한다" do
    empty_channel = Channel.create!(
      youtube_channel_id: "UC_empty_score_001",
      name: "점수 없는 채널"
    )

    get "/api/v1/channels/#{empty_channel.id}/scores",
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 0, json["scores"].length
  end

  test "index: limit 파라미터로 최근 N개만 가져올 수 있다" do
    get "/api/v1/channels/#{@channel.id}/scores",
      params: { limit: 2 },
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json["scores"].length
  end

  test "index: start_date와 end_date로 기간 필터링이 가능하다" do
    get "/api/v1/channels/#{@channel.id}/scores",
      params: { start_date: 20.days.ago.iso8601, end_date: Time.current.iso8601 },
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    # 30일 전 점수는 제외, 15일 전 + 1일 전 = 2개
    assert_equal 2, json["scores"].length
  end

  test "index: 다른 채널의 점수는 포함하지 않는다" do
    other_channel = Channel.create!(
      youtube_channel_id: "UC_other_api_001",
      name: "다른 채널"
    )
    ChannelScore.create!(
      channel: other_channel, score: 50.0, recorded_at: Time.current
    )

    get "/api/v1/channels/#{@channel.id}/scores",
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    # 다른 채널 점수 제외, 자기 채널 3개만
    assert_equal 3, json["scores"].length
    json["scores"].each do |s|
      assert_equal @channel.id, s["channel_id"]
    end
  end

  test "index: score 값이 올바른 형식으로 반환된다" do
    get "/api/v1/channels/#{@channel.id}/scores",
      headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    latest = json["scores"].last
    assert_equal "85.0", latest["score"]
    assert_equal "82.0", latest["accuracy_rate"]
  end
end
