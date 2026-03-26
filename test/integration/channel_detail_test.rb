# frozen_string_literal: true

# @TASK P3-S1-T1 - 채널 상세 화면 UI 통합 테스트
# @SPEC specs/screens/b2c-channel-detail.yaml
# ChannelHeader, SubMetrics, ScoreTrendChart, CheckHistory 컴포넌트를 검증한다.
require "test_helper"

class ChannelDetailTest < ActionDispatch::IntegrationTest
  # 테스트용 채널, 점수, 팩트체크 데이터를 사전에 준비한다.
  setup do
    @channel = Channel.create!(
      youtube_channel_id: "UC_test_channel_detail",
      name: "OO경제TV",
      description: "경제 뉴스 채널입니다.",
      subscriber_count: 452_000,
      category: "경제",
      trust_score: 38.0,
      total_checks: 5,
      thumbnail_url: nil
    )

    @user = User.create!(
      email: "channel_detail_test@example.com",
      name: "채널테스터",
      user_type: 0,
      is_active: true
    )

    # 신뢰도 추이 데이터 (ScoreTrendChart에서 사용)
    @score1 = ChannelScore.create!(
      channel: @channel,
      score: 30.0,
      accuracy_rate: 28.0,
      source_citation_rate: 15.0,
      consistency_score: 50.0,
      recorded_at: 3.months.ago
    )

    @score2 = ChannelScore.create!(
      channel: @channel,
      score: 38.0,
      accuracy_rate: 35.0,
      source_citation_rate: 22.0,
      consistency_score: 58.0,
      recorded_at: 1.month.ago
    )

    # 팩트체크 이력 (CheckHistory에서 사용)
    @fact_check1 = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=ch_detail_01",
      video_title: "부동산 폭락 시작됐다",
      overall_score: 32.0,
      status: :completed,
      completed_at: 2.days.ago
    )

    @fact_check2 = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=ch_detail_02",
      video_title: "금리 인하 가능성 분석",
      overall_score: 51.0,
      status: :completed,
      completed_at: 5.days.ago
    )
  end

  # 채널 상세 페이지가 정상 응답(200)을 반환하는지 확인
  test "채널 상세 페이지가 정상적으로 로드된다" do
    get channel_path(@channel.id)
    assert_response :success
  end

  # 페이지 타이틀이 채널명을 포함하는지 확인
  test "페이지 타이틀이 채널명을 포함한다" do
    get channel_path(@channel.id)
    assert_select "title", text: /OO경제TV/
  end

  # ChannelHeader: 채널명이 표시되는지 확인
  test "채널명이 ChannelHeader에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='channel-header']" do
      assert_select "[data-field='channel-name']", text: /OO경제TV/
    end
  end

  # ChannelHeader: 구독자 수가 표시되는지 확인
  test "구독자 수가 ChannelHeader에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='channel-header']" do
      assert_select "[data-field='subscriber-count']"
    end
  end

  # ChannelHeader: 신뢰도 점수가 표시되는지 확인
  test "신뢰도 점수가 ChannelHeader에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='channel-header']" do
      assert_select "[data-field='trust-score']", text: /38/
    end
  end

  # ChannelHeader: 카테고리가 표시되는지 확인
  test "카테고리가 ChannelHeader에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='channel-header']" do
      assert_select "[data-field='category']", text: /경제/
    end
  end

  # SubMetrics: 3개 상세 지표 카드 컴포넌트가 표시되는지 확인
  test "SubMetrics 컴포넌트가 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='sub-metrics']"
  end

  # SubMetrics: 정확도 지표가 표시되는지 확인
  test "정확도 지표가 SubMetrics에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='sub-metrics']" do
      assert_select "[data-field='accuracy-rate']"
    end
  end

  # SubMetrics: 출처 인용률 지표가 표시되는지 확인
  test "출처 인용률 지표가 SubMetrics에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='sub-metrics']" do
      assert_select "[data-field='source-citation-rate']"
    end
  end

  # SubMetrics: 논조 일관성 지표가 표시되는지 확인
  test "논조 일관성 지표가 SubMetrics에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='sub-metrics']" do
      assert_select "[data-field='consistency-score']"
    end
  end

  # ScoreTrendChart: 신뢰도 추이 차트 컴포넌트가 표시되는지 확인
  test "ScoreTrendChart 컴포넌트가 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='score-trend-chart']"
  end

  # CheckHistory: 팩트체크 이력 목록 컴포넌트가 표시되는지 확인
  test "CheckHistory 컴포넌트가 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='check-history']"
  end

  # CheckHistory: 팩트체크 이력 항목이 표시되는지 확인
  test "팩트체크 이력 항목이 CheckHistory에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='check-history']" do
      assert_select "[data-component='check-history-item']"
    end
  end

  # CheckHistory: 영상 제목이 이력 항목에 표시되는지 확인
  test "영상 제목이 CheckHistory 항목에 표시된다" do
    get channel_path(@channel.id)
    assert_select "[data-component='check-history']" do
      assert_select "[data-field='video-title']", text: /부동산/
    end
  end

  # CheckHistory: 이력 항목이 /reports/:id 링크를 가지는지 확인
  test "CheckHistory 항목이 리포트 상세 링크를 가진다" do
    get channel_path(@channel.id)
    assert_select "[data-component='check-history-item'] a[href*='/reports/']"
  end

  # 존재하지 않는 채널 요청 시 404 처리 확인
  test "존재하지 않는 채널은 404를 반환한다" do
    get channel_path("nonexistent-channel-id-000")
    assert_response :not_found
  end

  teardown do
    # 테스트 데이터 정리 (의존성 순서대로 삭제)
    FactCheck.where(channel_id: @channel&.id).delete_all
    ChannelScore.where(channel_id: @channel&.id).delete_all
    Channel.where(id: @channel&.id).delete_all
    User.where(id: @user&.id).delete_all
  end
end
