# frozen_string_literal: true

# @TASK P3-R1-T1 - Channel 모델 테스트
# @TEST test/models/channel_test.rb
require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(
      youtube_channel_id: "UC_test_channel_001",
      name: "테스트 뉴스 채널",
      description: "테스트용 채널입니다",
      subscriber_count: 100_000,
      category: "시사",
      trust_score: 85.5,
      total_checks: 10,
      thumbnail_url: "https://example.com/thumb.jpg"
    )
  end

  # --- 유효성 검사 ---

  test "유효한 속성으로 생성할 수 있다" do
    assert @channel.valid?
    assert @channel.persisted?
  end

  test "youtube_channel_id가 없으면 유효하지 않다" do
    channel = Channel.new(name: "채널")
    assert_not channel.valid?
    assert_includes channel.errors[:youtube_channel_id], "can't be blank"
  end

  test "name이 없으면 유효하지 않다" do
    channel = Channel.new(youtube_channel_id: "UC_unique_123")
    assert_not channel.valid?
    assert_includes channel.errors[:name], "can't be blank"
  end

  test "youtube_channel_id는 중복될 수 없다" do
    duplicate = Channel.new(
      youtube_channel_id: "UC_test_channel_001",
      name: "다른 채널"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:youtube_channel_id], "has already been taken"
  end

  # --- 연관 관계 ---

  test "fact_checks 연관 관계가 존재한다" do
    assert_respond_to @channel, :fact_checks
  end

  test "channel_scores 연관 관계가 존재한다" do
    assert_respond_to @channel, :channel_scores
  end

  test "channel_tags 연관 관계가 존재한다" do
    assert_respond_to @channel, :channel_tags
  end

  test "채널 삭제 시 관련 fact_checks도 삭제된다" do
    user = User.create!(email: "assoc_test@example.com", user_type: :b2c)
    FactCheck.create!(
      user: user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=assocTest",
      youtube_video_id: "assocTest"
    )

    assert_difference("FactCheck.count", -1) do
      @channel.destroy
    end
  end

  # --- Scope: by_category ---

  test "by_category 스코프는 해당 카테고리의 채널만 반환한다" do
    politics_channel = Channel.create!(
      youtube_channel_id: "UC_politics_001",
      name: "정치 채널",
      category: "정치"
    )

    results = Channel.by_category("시사")
    assert_includes results, @channel
    assert_not_includes results, politics_channel
  end

  test "by_category 스코프에 nil을 전달하면 category가 nil인 채널을 반환한다" do
    no_category = Channel.create!(
      youtube_channel_id: "UC_nocategory_001",
      name: "카테고리 없는 채널"
    )

    results = Channel.by_category(nil)
    assert_includes results, no_category
    assert_not_includes results, @channel
  end

  # --- Scope: ranked_by_trust (trust_score 내림차순) ---

  test "ranked_by_trust 스코프는 trust_score 내림차순으로 정렬한다" do
    low_trust = Channel.create!(
      youtube_channel_id: "UC_low_trust_001",
      name: "저신뢰 채널",
      trust_score: 30.0
    )
    high_trust = Channel.create!(
      youtube_channel_id: "UC_high_trust_001",
      name: "고신뢰 채널",
      trust_score: 95.0
    )

    results = Channel.ranked_by_trust
    scores = results.map(&:trust_score)
    # 내림차순 정렬 확인
    assert_equal scores.sort.reverse, scores
    assert_equal high_trust, results.first
  end

  # --- Scope: search_by_name ---

  test "search_by_name 스코프는 이름에 검색어가 포함된 채널을 반환한다" do
    other = Channel.create!(
      youtube_channel_id: "UC_other_001",
      name: "다른 정치 토론 채널"
    )

    results = Channel.search_by_name("테스트")
    assert_includes results, @channel
    assert_not_includes results, other
  end

  test "search_by_name 스코프는 대소문자를 구분하지 않는다" do
    english_channel = Channel.create!(
      youtube_channel_id: "UC_english_001",
      name: "News Channel ABC"
    )

    results = Channel.search_by_name("news")
    assert_includes results, english_channel
  end
end
