# frozen_string_literal: true

# @TASK P3-S1-V - 채널 상세 연결점 검증
# @TASK P3-S2-V - 채널 랭킹 연결점 검증
# 채널 상세 화면과 채널 랭킹 화면의 필드, 엔드포인트, 라우트, 네비게이션이 올바르게 연결되었는지 검증하는 통합 테스트
require "test_helper"

class Phase3VerificationTest < ActionDispatch::IntegrationTest
  # ========== 테스트 데이터 준비 ==========

  setup do
    # 테스트용 사용자 (팩트체크 이력 생성용)
    @user = User.create!(
      email: "phase3_test@example.com",
      name: "P3 테스터",
      user_type: 0,
      is_active: true
    )

    # 세션 토큰 생성 (API 인증용)
    @session = Session.create!(user: @user)
    @auth_headers = { "X-Session-Token" => @session.token }

    # P3-S1-V & P3-S2-V 검증용 채널
    @channel1 = Channel.create!(
      youtube_channel_id: "UC_channel_01_ranking",
      name: "정치뉴스TV",
      description: "정치 뉴스 채널",
      category: "정치",
      subscriber_count: 750_000,
      trust_score: 75.0,
      total_checks: 12,
      thumbnail_url: "https://example.com/thumb1.jpg"
    )

    @channel2 = Channel.create!(
      youtube_channel_id: "UC_channel_02_ranking",
      name: "경제분석채널",
      description: "경제 분석 채널",
      category: "경제",
      subscriber_count: 450_000,
      trust_score: 62.0,
      total_checks: 8,
      thumbnail_url: "https://example.com/thumb2.jpg"
    )

    @channel3 = Channel.create!(
      youtube_channel_id: "UC_channel_03_ranking",
      name: "사회이슈분석",
      description: "사회 이슈 채널",
      category: "사회",
      subscriber_count: 320_000,
      trust_score: 55.0,
      total_checks: 5,
      thumbnail_url: nil
    )

    # 채널 점수 이력 (P3-S1-V: ScoreTrendChart 테스트용)
    @score1 = ChannelScore.create!(
      channel: @channel1,
      score: 70.0,
      accuracy_rate: 68.0,
      source_citation_rate: 72.0,
      consistency_score: 74.0,
      recorded_at: 2.months.ago
    )

    @score2 = ChannelScore.create!(
      channel: @channel1,
      score: 75.0,
      accuracy_rate: 73.0,
      source_citation_rate: 78.0,
      consistency_score: 80.0,
      recorded_at: 1.month.ago
    )

    # 팩트체크 이력 (P3-S1-V: CheckHistory 테스트용)
    @fact_check1 = FactCheck.create!(
      user: @user,
      channel: @channel1,
      youtube_url: "https://www.youtube.com/watch?v=test_ch1_01",
      video_title: "[정치] 정책 발표 팩트체크",
      overall_score: 72.0,
      status: :completed,
      completed_at: 2.days.ago
    )

    @fact_check2 = FactCheck.create!(
      user: @user,
      channel: @channel1,
      youtube_url: "https://www.youtube.com/watch?v=test_ch1_02",
      video_title: "[정치] 선거 공약 검증",
      overall_score: 78.0,
      status: :completed,
      completed_at: 5.days.ago
    )
  end

  # ========== P3-S1-V: 채널 상세 연결점 검증 ==========

  # P3-S1-V-1: GET /api/v1/channels/:id 라우트가 존재하는가?
  test "P3-S1-V-1: GET /api/v1/channels/:id 라우트가 존재한다" do
    assert_routing(
      { path: "/api/v1/channels/#{@channel1.id}", method: :get },
      { controller: "api/v1/channels", action: "show", id: @channel1.id.to_s }
    )
  end

  # P3-S1-V-2: GET /api/v1/channels/:channel_id/scores 라우트가 존재하는가?
  test "P3-S1-V-2: GET /api/v1/channels/:channel_id/scores 라우트가 존재한다" do
    assert_routing(
      { path: "/api/v1/channels/#{@channel1.id}/scores", method: :get },
      { controller: "api/v1/channel_scores", action: "index", channel_id: @channel1.id.to_s }
    )
  end

  # P3-S1-V-3: 채널 상세 API가 channels.[name, trust_score, subscriber_count, category] 필드를 반환하는가?
  test "P3-S1-V-3: 채널 상세 API가 name, trust_score, subscriber_count, category 필드를 반환한다" do
    get "/api/v1/channels/#{@channel1.id}", headers: @auth_headers

    assert_response :success
    data = JSON.parse(response.body)

    # 필드 검증
    assert_includes data.keys, "name"
    assert_includes data.keys, "trust_score"
    assert_includes data.keys, "subscriber_count"
    assert_includes data.keys, "category"

    # 값 검증
    assert_equal @channel1.name, data["name"]
    assert_equal @channel1.trust_score.to_s, data["trust_score"]
    assert_equal @channel1.subscriber_count, data["subscriber_count"]
    assert_equal @channel1.category, data["category"]
  end

  # P3-S1-V-4: 채널 점수 API가 channel_scores.[score, accuracy_rate, source_citation_rate, consistency_score] 필드를 반환하는가?
  test "P3-S1-V-4: 채널 점수 API가 score, accuracy_rate, source_citation_rate, consistency_score 필드를 반환한다" do
    get "/api/v1/channels/#{@channel1.id}/scores", headers: @auth_headers

    assert_response :success
    data = JSON.parse(response.body)

    # 점수 배열이 반환되는가?
    assert_includes data.keys, "scores"
    assert_instance_of Array, data["scores"]
    assert data["scores"].length > 0

    # 필드 검증
    score = data["scores"].first
    assert_includes score.keys, "score"
    assert_includes score.keys, "accuracy_rate"
    assert_includes score.keys, "source_citation_rate"
    assert_includes score.keys, "consistency_score"
  end

  # P3-S1-V-5: 채널 상세 뷰에서 required 필드(name, trust_score, subscriber_count, category)를 사용하는가?
  test "P3-S1-V-5: 채널 상세 뷰가 name, trust_score, subscriber_count, category 필드를 렌더링한다" do
    get channel_path(@channel1.id)

    assert_response :success

    # 채널명 (data-field="channel-name")
    assert_select "[data-field='channel-name']", text: /정치뉴스TV/

    # 신뢰도 점수 (data-field="trust-score")
    assert_select "[data-field='trust-score']", text: /75/

    # 구독자 수 (data-field="subscriber-count")
    assert_select "[data-field='subscriber-count']"

    # 카테고리 (data-field="category")
    assert_select "[data-field='category']", text: /정치/
  end

  # P3-S1-V-6: 채널 상세 뷰에서 channel_scores의 세부 지표(accuracy_rate, source_citation_rate, consistency_score)를 렌더링하는가?
  test "P3-S1-V-6: 채널 상세 뷰가 accuracy_rate, source_citation_rate, consistency_score를 렌더링한다" do
    get channel_path(@channel1.id)

    assert_response :success

    # 정확도 (data-field="accuracy-rate")
    assert_select "[data-field='accuracy-rate']"

    # 출처 인용률 (data-field="source-citation-rate")
    assert_select "[data-field='source-citation-rate']"

    # 논조 일관성 (data-field="consistency-score")
    assert_select "[data-field='consistency-score']"
  end

  # P3-S1-V-7: 채널 상세 뷰에서 팩트체크 이력을 렌더링하는가?
  test "P3-S1-V-7: 채널 상세 뷰가 CheckHistory 항목들을 렌더링한다" do
    get channel_path(@channel1.id)

    assert_response :success

    # CheckHistory 섹션이 존재하는가?
    assert_select "[data-component='check-history']"

    # 팩트체크 항목이 렌더링되는가?
    assert_select "[data-component='check-history-item']"
  end

  # P3-S1-V-8: /reports/:id 라우트가 존재하는가?
  test "P3-S1-V-8: /reports/:id 라우트가 존재한다" do
    assert_routing(
      { path: "/reports/#{@fact_check1.id}", method: :get },
      { controller: "reports", action: "show", id: @fact_check1.id.to_s }
    )
  end

  # P3-S1-V-9: 채널 상세 뷰의 CheckHistory 항목이 /reports/:id로 이동하는가?
  test "P3-S1-V-9: 채널 상세 뷰의 CheckHistory 항목이 /reports/:id로 이동한다" do
    get channel_path(@channel1.id)

    assert_response :success

    # CheckHistory 항목이 report 경로로 링크되는가?
    assert_select "a[href='#{report_path(@fact_check1.id)}']"
  end

  # ========== P3-S2-V: 채널 랭킹 연결점 검증 ==========

  # P3-S2-V-1: GET /api/v1/channels (category 필터) 라우트가 존재하는가?
  test "P3-S2-V-1: GET /api/v1/channels (category 필터) 라우트가 존재한다" do
    assert_routing(
      { path: "/api/v1/channels", method: :get },
      { controller: "api/v1/channels", action: "index" }
    )
  end

  # P3-S2-V-2: 채널 목록 API가 channels.[id, name, trust_score, category, total_checks] 필드를 반환하는가?
  test "P3-S2-V-2: 채널 목록 API가 id, name, trust_score, category, total_checks 필드를 반환한다" do
    get "/api/v1/channels", headers: @auth_headers

    assert_response :success
    data = JSON.parse(response.body)

    # channels 배열이 반환되는가?
    assert_includes data.keys, "channels"
    assert_instance_of Array, data["channels"]
    assert data["channels"].length > 0

    # 필드 검증
    channel = data["channels"].first
    assert_includes channel.keys, "id"
    assert_includes channel.keys, "name"
    assert_includes channel.keys, "trust_score"
    assert_includes channel.keys, "category"
    assert_includes channel.keys, "total_checks"
  end

  # P3-S2-V-3: 채널 목록 API가 category 필터를 지원하는가?
  test "P3-S2-V-3: 채널 목록 API가 category 필터를 지원한다" do
    get "/api/v1/channels", params: { category: "정치" }, headers: @auth_headers

    assert_response :success
    data = JSON.parse(response.body)

    # 정치 카테고리 채널만 반환되는가?
    data["channels"].each do |channel|
      assert_equal "정치", channel["category"]
    end
  end

  # P3-S2-V-4: 채널 목록 API가 신뢰도 내림차순(랭킹)으로 반환하는가?
  test "P3-S2-V-4: 채널 목록 API가 trust_score 내림차순으로 반환한다" do
    get "/api/v1/channels", headers: @auth_headers

    assert_response :success
    data = JSON.parse(response.body)

    # 신뢰도 내림차순 검증
    channels = data["channels"]
    trust_scores = channels.map { |ch| ch["trust_score"].to_f }
    assert_equal trust_scores.sort.reverse, trust_scores
  end

  # P3-S2-V-5: 채널 랭킹 뷰가 존재하는가? (/ranking 페이지)
  test "P3-S2-V-5: 채널 랭킹 뷰(/ranking)가 존재하고 채널을 렌더링한다" do
    get ranking_path

    assert_response :success

    # 랭킹 페이지가 로드되는가?
    assert_select "title", text: /랭킹/i
  end

  # P3-S2-V-6: 채널 랭킹 뷰가 channels.[id, name, trust_score, category, total_checks] 필드를 사용하는가?
  test "P3-S2-V-6: 채널 랭킹 뷰가 name, trust_score, category, total_checks 필드를 렌더링한다" do
    get ranking_path

    assert_response :success

    # 랭킹 목록 섹션
    assert_select "[data-component='ranking-list']"

    # 랭킹 항목 (최소한 3개 채널)
    ranking_items = css_select("[data-component='ranking-item']")
    assert ranking_items.length >= 3

    # 채널명이 포함되는가?
    assert_select "[data-component='ranking-list']", text: /정치뉴스TV/
    assert_select "[data-component='ranking-list']", text: /경제분석채널/
    assert_select "[data-component='ranking-list']", text: /사회이슈분석/
  end

  # P3-S2-V-7: 채널 랭킹 뷰의 RankingList 항목이 /channels/:id로 이동하는가?
  test "P3-S2-V-7: 채널 랭킹 뷰의 RankingList 항목이 /channels/:id로 이동한다" do
    get ranking_path

    assert_response :success

    # 채널 링크가 존재하는가?
    assert_select "a[href='#{channel_path(@channel1.id)}']"
    assert_select "a[href='#{channel_path(@channel2.id)}']"
    assert_select "a[href='#{channel_path(@channel3.id)}']"
  end

  # P3-S2-V-8: 채널 랭킹 뷰가 category 탭으로 필터링을 지원하는가?
  test "P3-S2-V-8: 채널 랭킹 뷰가 카테고리 탭으로 필터링을 지원한다" do
    # 경제 카테고리로 필터
    get ranking_path, params: { category: "경제" }

    assert_response :success

    # 경제 카테고리 채널만 표시되는가?
    assert_select "[data-component='ranking-list']", text: /경제분석채널/
  end

  # P3-S2-V-9: 채널 랭킹이 trust_score 내림차순으로 정렬되는가?
  test "P3-S2-V-9: 채널 랭킹이 trust_score 내림차순으로 정렬된다" do
    get ranking_path

    assert_response :success

    # 랭킹 항목의 점수 순서 확인
    # 첫 번째는 75.0 (정치뉴스TV)
    ranking_items = css_select("[data-component='ranking-item']")
    assert ranking_items.length > 0
    first_item = ranking_items.first
    assert first_item.present?
    assert first_item.text.include?("정치뉴스TV") || first_item.text.include?("75")
  end

  # ========== 추가 검증: 404 처리 ==========

  # P3-S1-V-10: 존재하지 않는 채널 조회 시 404 응답
  test "P3-S1-V-10: 존재하지 않는 채널 조회 시 404 응답을 반환한다" do
    get channel_path(999_999)

    assert_response :not_found
  end

  # P3-S1-V-11: 존재하지 않는 채널의 scores API 조회 시 404 응답
  test "P3-S1-V-11: 존재하지 않는 채널의 scores API 조회 시 404 응답을 반환한다" do
    get "/api/v1/channels/999999/scores", headers: @auth_headers

    assert_response :not_found
  end

  # P3-S1-V-12: 채널 상세 뷰에서 description이 있는 경우 표시
  test "P3-S1-V-12: 채널 상세 뷰가 description을 렌더링한다" do
    get channel_path(@channel1.id)

    assert_response :success

    # 설명이 표시되는가?
    assert_select "p", text: /정치 뉴스 채널/
  end

  # P3-S1-V-13: 채널 상세 뷰에서 thumbnail이 없는 경우 이니셜 아바타 표시
  test "P3-S1-V-13: 채널 상세 뷰가 thumbnail이 없을 때 이니셜 아바타를 렌더링한다" do
    get channel_path(@channel3.id)

    assert_response :success

    # 이니셜이 포함되어 있는가?
    assert_select "span", text: /사/
  end

  # P3-S2-V-10: 채널 목록 API의 메타데이터 (페이지네이션)
  test "P3-S2-V-10: 채널 목록 API가 메타데이터(pagination)를 반환한다" do
    get "/api/v1/channels", headers: @auth_headers

    assert_response :success
    data = JSON.parse(response.body)

    # 메타 정보 검증
    assert_includes data.keys, "meta"
    meta = data["meta"]
    assert_includes meta.keys, "current_page"
    assert_includes meta.keys, "per_page"
    assert_includes meta.keys, "total_count"
    assert_includes meta.keys, "total_pages"
  end

  # ========== 테스트 정리 ==========

  teardown do
    # 생성된 팩트체크 삭제
    @fact_check1.destroy
    @fact_check2.destroy

    # 생성된 점수 이력 삭제
    @score1.destroy
    @score2.destroy

    # 생성된 채널 삭제
    @channel1.destroy
    @channel2.destroy
    @channel3.destroy

    # 테스트 사용자 삭제
    @user.destroy
  end
end
