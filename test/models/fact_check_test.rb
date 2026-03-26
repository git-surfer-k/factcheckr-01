# frozen_string_literal: true

# @TASK P2-R1-T1 - FactCheck 모델 테스트
# @TEST test/models/fact_check_test.rb
require "test_helper"

class FactCheckTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "checker@example.com", user_type: :b2c)
    @channel = Channel.create!(
      youtube_channel_id: "UC_test_channel_001",
      name: "테스트 뉴스 채널"
    )
    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      youtube_video_id: "dQw4w9WgXcQ",
      video_title: "테스트 영상"
    )
  end

  # --- 연관 관계 ---

  test "user 연관 관계가 존재한다" do
    assert_respond_to @fact_check, :user
    assert_equal @user, @fact_check.user
  end

  test "channel 연관 관계가 존재한다" do
    assert_respond_to @fact_check, :channel
    assert_equal @channel, @fact_check.channel
  end

  test "claims 연관 관계가 존재한다" do
    assert_respond_to @fact_check, :claims
  end

  # --- 유효성 검사 ---

  test "user_id가 없으면 유효하지 않다" do
    fc = FactCheck.new(channel: @channel, youtube_url: "https://www.youtube.com/watch?v=abc123")
    assert_not fc.valid?
    assert_includes fc.errors[:user_id], "can't be blank"
  end

  test "channel_id가 없으면 유효하지 않다" do
    fc = FactCheck.new(user: @user, youtube_url: "https://www.youtube.com/watch?v=abc123")
    assert_not fc.valid?
    assert_includes fc.errors[:channel_id], "can't be blank"
  end

  test "youtube_url이 없으면 유효하지 않다" do
    fc = FactCheck.new(user: @user, channel: @channel)
    assert_not fc.valid?
    assert_includes fc.errors[:youtube_url], "can't be blank"
  end

  test "올바른 유튜브 URL만 허용한다" do
    valid_urls = [
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "https://youtube.com/watch?v=dQw4w9WgXcQ",
      "https://youtu.be/dQw4w9WgXcQ",
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120"
    ]

    valid_urls.each do |url|
      fc = FactCheck.new(user: @user, channel: @channel, youtube_url: url)
      fc.valid?
      assert_not fc.errors[:youtube_url].any? { |e| e.include?("올바른") },
        "#{url}이 유효하지 않다고 판단됨"
    end
  end

  test "유튜브가 아닌 URL은 거부한다" do
    invalid_urls = [
      "https://www.google.com/watch?v=abc123",
      "https://vimeo.com/123456",
      "not-a-url"
    ]

    invalid_urls.each do |url|
      fc = FactCheck.new(user: @user, channel: @channel, youtube_url: url)
      assert_not fc.valid?, "#{url}이 유효하다고 판단됨"
    end
  end

  # --- Status Enum ---

  test "기본 status는 pending이다" do
    fc = FactCheck.new(user: @user, channel: @channel, youtube_url: "https://youtube.com/watch?v=abc")
    assert fc.pending?
  end

  test "status enum 값이 올바르게 설정된다" do
    assert @fact_check.pending?

    @fact_check.status = :analyzing
    assert @fact_check.analyzing?

    @fact_check.status = :completed
    assert @fact_check.completed?

    @fact_check.status = :failed
    assert @fact_check.failed?
  end

  # --- youtube_video_id 추출 ---

  test "youtube_url에서 youtube_video_id를 자동 추출한다 (일반 URL)" do
    fc = FactCheck.new(
      user: @user, channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=abc123XYZ_0"
    )
    fc.valid?
    assert_equal "abc123XYZ_0", fc.youtube_video_id
  end

  test "youtube_url에서 youtube_video_id를 자동 추출한다 (단축 URL)" do
    fc = FactCheck.new(
      user: @user, channel: @channel,
      youtube_url: "https://youtu.be/abc123XYZ_0"
    )
    fc.valid?
    assert_equal "abc123XYZ_0", fc.youtube_video_id
  end

  test "youtube_url에서 youtube_video_id를 자동 추출한다 (파라미터 포함)" do
    fc = FactCheck.new(
      user: @user, channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=abc123XYZ_0&t=120&list=PLxyz"
    )
    fc.valid?
    assert_equal "abc123XYZ_0", fc.youtube_video_id
  end

  # --- Scope ---

  test "by_user 스코프는 특정 사용자의 팩트체크만 반환한다" do
    other_user = User.create!(email: "other@example.com", user_type: :b2c)
    other_fc = FactCheck.create!(
      user: other_user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=other123",
      youtube_video_id: "other123"
    )

    results = FactCheck.by_user(@user.id)
    assert_includes results, @fact_check
    assert_not_includes results, other_fc
  end

  test "recent 스코프는 최신 순으로 정렬한다" do
    older_fc = FactCheck.create!(
      user: @user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=older123",
      youtube_video_id: "older123",
      created_at: 2.days.ago
    )

    results = FactCheck.recent
    assert_equal @fact_check, results.first
  end

  test "completed 스코프는 완료된 팩트체크만 반환한다" do
    @fact_check.update!(status: :completed, completed_at: Time.current)
    pending_fc = FactCheck.create!(
      user: @user, channel: @channel,
      youtube_url: "https://youtube.com/watch?v=pending123",
      youtube_video_id: "pending123",
      status: :pending
    )

    results = FactCheck.completed_checks
    assert_includes results, @fact_check
    assert_not_includes results, pending_fc
  end
end
