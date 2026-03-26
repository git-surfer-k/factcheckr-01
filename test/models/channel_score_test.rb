# frozen_string_literal: true

# @TASK P3-R2-T1 - ChannelScore 모델 테스트
# @TEST test/models/channel_score_test.rb
# scope(recent, by_period), association(belongs_to :channel) 검증
require "test_helper"

class ChannelScoreTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(
      youtube_channel_id: "UC_score_test_001",
      name: "점수 테스트 채널"
    )
  end

  # === Association ===

  test "belongs_to: channel 연관이 설정되어 있다" do
    score = ChannelScore.create!(
      channel: @channel,
      score: 80.0,
      recorded_at: Time.current
    )

    assert_equal @channel, score.channel
  end

  test "validates: channel_id가 없으면 저장 실패한다" do
    score = ChannelScore.new(score: 80.0, recorded_at: Time.current)
    assert_not score.valid?
    assert_includes score.errors[:channel_id], "can't be blank"
  end

  # === Scope: recent ===

  test "recent: recorded_at 내림차순으로 정렬한다" do
    old_score = ChannelScore.create!(
      channel: @channel, score: 70.0, recorded_at: 3.days.ago
    )
    new_score = ChannelScore.create!(
      channel: @channel, score: 85.0, recorded_at: 1.day.ago
    )
    mid_score = ChannelScore.create!(
      channel: @channel, score: 78.0, recorded_at: 2.days.ago
    )

    results = ChannelScore.recent
    assert_equal new_score.id, results.first.id
    assert_equal old_score.id, results.last.id
  end

  test "recent: limit으로 최근 N개만 가져올 수 있다" do
    5.times do |i|
      ChannelScore.create!(
        channel: @channel, score: 60.0 + i * 5,
        recorded_at: i.days.ago
      )
    end

    results = ChannelScore.recent.limit(3)
    assert_equal 3, results.count
  end

  # === Scope: by_period ===

  test "by_period: 특정 기간의 점수만 반환한다" do
    ChannelScore.create!(
      channel: @channel, score: 70.0, recorded_at: 30.days.ago
    )
    in_range = ChannelScore.create!(
      channel: @channel, score: 80.0, recorded_at: 5.days.ago
    )
    ChannelScore.create!(
      channel: @channel, score: 90.0, recorded_at: 60.days.ago
    )

    results = ChannelScore.by_period(10.days.ago, Time.current)
    assert_equal 1, results.count
    assert_equal in_range.id, results.first.id
  end

  test "by_period: 기간에 해당하는 점수가 없으면 빈 결과를 반환한다" do
    ChannelScore.create!(
      channel: @channel, score: 80.0, recorded_at: 30.days.ago
    )

    results = ChannelScore.by_period(5.days.ago, Time.current)
    assert_equal 0, results.count
  end

  # === Scope: by_channel ===

  test "by_channel: 특정 채널의 점수만 반환한다" do
    other_channel = Channel.create!(
      youtube_channel_id: "UC_other_score_001",
      name: "다른 채널"
    )

    ChannelScore.create!(
      channel: @channel, score: 80.0, recorded_at: Time.current
    )
    ChannelScore.create!(
      channel: other_channel, score: 60.0, recorded_at: Time.current
    )

    results = ChannelScore.by_channel(@channel.id)
    assert_equal 1, results.count
  end

  # === 필드 기본값 ===

  test "create: 기본값이 올바르게 설정된다" do
    score = ChannelScore.create!(
      channel: @channel,
      recorded_at: Time.current
    )

    assert_equal 0.0, score.score.to_f
    assert_equal 0.0, score.accuracy_rate.to_f
    assert_equal 0.0, score.source_citation_rate.to_f
    assert_equal 0.0, score.consistency_score.to_f
  end

  # === Scope: in_date_range (기존 별칭 호환) ===

  test "in_date_range: by_period와 동일하게 동작한다" do
    in_range = ChannelScore.create!(
      channel: @channel, score: 85.0, recorded_at: 3.days.ago
    )

    results = ChannelScore.in_date_range(5.days.ago, Time.current)
    assert_equal 1, results.count
    assert_equal in_range.id, results.first.id
  end
end
