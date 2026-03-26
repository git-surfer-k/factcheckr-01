# frozen_string_literal: true

# @TASK P2-R3-T1 - NewsSources 컨트롤러 테스트
# @TEST test/controllers/api/v1/news_sources_controller_test.rb
require "test_helper"

class Api::V1::NewsSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "factchecker@example.com", user_type: :b2c)
    @session = @user.create_session!
    @auth_headers = { "X-Session-Token" => @session.token }

    @channel = Channel.create!(youtube_channel_id: "UC_test_456", name: "뉴스 채널")
    @fact_check = FactCheck.create!(
      user: @user, channel: @channel, status: :completed,
      youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    )
    @claim = Claim.create!(fact_check: @fact_check, verdict: :true_claim)

    @news_source_1 = NewsSource.create!(
      claim: @claim,
      title: "관련 뉴스 기사 1",
      url: "https://example.com/news/1",
      publisher: "한겨레",
      author: "김기자",
      published_at: 1.day.ago,
      relevance_score: 0.95,
      bigkinds_doc_id: "BK_001"
    )

    @news_source_2 = NewsSource.create!(
      claim: @claim,
      title: "관련 뉴스 기사 2",
      url: "https://example.com/news/2",
      publisher: "경향신문",
      author: "이기자",
      published_at: 2.days.ago,
      relevance_score: 0.75,
      bigkinds_doc_id: "BK_002"
    )
  end

  # ===========================================
  # GET /api/v1/claims/:claim_id/news_sources
  # ===========================================

  test "index: 주장에 연결된 근거 뉴스 목록을 조회한다" do
    get "/api/v1/claims/#{@claim.id}/news_sources", headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json["news_sources"].length
  end

  test "index: 응답에 필수 필드가 모두 포함된다" do
    get "/api/v1/claims/#{@claim.id}/news_sources", headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    news = json["news_sources"].first

    assert_not_nil news["id"]
    assert_not_nil news["claim_id"]
    assert_not_nil news["title"]
    assert_not_nil news["url"]
    assert_not_nil news["publisher"]
    assert_not_nil news["author"]
    assert_not_nil news["published_at"]
    assert_not_nil news["relevance_score"]
    assert_not_nil news["bigkinds_doc_id"]
  end

  test "index: relevance_score 내림차순으로 정렬된다" do
    get "/api/v1/claims/#{@claim.id}/news_sources", headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    scores = json["news_sources"].map { |n| n["relevance_score"].to_f }
    assert_equal scores, scores.sort.reverse
  end

  test "index: 존재하지 않는 claim_id로 요청하면 404를 반환한다" do
    get "/api/v1/claims/nonexistent-uuid/news_sources", headers: @auth_headers, as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_includes json["detail"], "주장"
  end

  test "index: 다른 사용자의 claim에 대해 요청하면 403을 반환한다" do
    other_user = User.create!(email: "other@example.com", user_type: :b2c)
    other_fact_check = FactCheck.create!(
      user: other_user, channel: @channel, status: :completed,
      youtube_url: "https://www.youtube.com/watch?v=xvFZjo5PgG0"
    )
    other_claim = Claim.create!(fact_check: other_fact_check, verdict: :false_claim)
    NewsSource.create!(
      claim: other_claim,
      title: "다른 사용자 기사",
      url: "https://example.com/other"
    )

    get "/api/v1/claims/#{other_claim.id}/news_sources", headers: @auth_headers, as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_includes json["detail"], "권한"
  end

  test "index: 인증 없이 요청하면 401 에러" do
    get "/api/v1/claims/#{@claim.id}/news_sources", as: :json

    assert_response :unauthorized
  end

  test "index: 근거 뉴스가 없으면 빈 배열을 반환한다" do
    empty_claim = Claim.create!(fact_check: @fact_check, verdict: :mostly_true)

    get "/api/v1/claims/#{empty_claim.id}/news_sources", headers: @auth_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 0, json["news_sources"].length
  end
end
