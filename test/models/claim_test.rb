# frozen_string_literal: true

# @TASK P2-R2-T1 - Claim 모델 테스트
# @TEST test/models/claim_test.rb
require "test_helper"

class ClaimTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "claim-test@example.com", user_type: :b2c)
    @channel = Channel.create!(youtube_channel_id: "UC_claim_test", name: "Claim Test Channel")
    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=test_claim1",
      status: :completed
    )
  end

  # --- verdict enum 테스트 ---

  test "verdict enum 에 unverified 가 존재한다" do
    claim = Claim.new(fact_check: @fact_check, verdict: :unverified)
    assert claim.unverified?
  end

  test "verdict enum 에 true_claim 이 존재한다" do
    claim = Claim.new(fact_check: @fact_check, verdict: :true_claim)
    assert claim.true_claim?
  end

  test "verdict enum 에 mostly_true 가 존재한다" do
    claim = Claim.new(fact_check: @fact_check, verdict: :mostly_true)
    assert claim.mostly_true?
  end

  test "verdict enum 에 half_true 가 존재한다" do
    claim = Claim.new(fact_check: @fact_check, verdict: :half_true)
    assert claim.half_true?
  end

  test "verdict enum 에 mostly_false 가 존재한다" do
    claim = Claim.new(fact_check: @fact_check, verdict: :mostly_false)
    assert claim.mostly_false?
  end

  test "verdict enum 에 false_claim 이 존재한다" do
    claim = Claim.new(fact_check: @fact_check, verdict: :false_claim)
    assert claim.false_claim?
  end

  # --- validation 테스트 ---

  test "fact_check_id 가 없으면 유효하지 않다" do
    claim = Claim.new(verdict: :unverified)
    assert_not claim.valid?
    assert_includes claim.errors[:fact_check_id], "can't be blank"
  end

  test "verdict 가 없으면 유효하지 않다" do
    claim = Claim.new(fact_check: @fact_check, verdict: nil)
    assert_not claim.valid?
    assert_includes claim.errors[:verdict], "can't be blank"
  end

  test "모든 필드가 있으면 유효하다" do
    claim = Claim.new(
      fact_check: @fact_check,
      verdict: :true_claim,
      claim_text: "테스트 주장",
      confidence: 0.95,
      explanation: "근거 설명",
      timestamp_start: 10,
      timestamp_end: 30
    )
    assert claim.valid?
  end

  # --- scope 테스트 ---

  test "by_fact_check 스코프는 특정 fact_check 의 claim 만 반환한다" do
    claim1 = Claim.create!(fact_check: @fact_check, verdict: :true_claim, claim_text: "주장 1")

    other_fc = FactCheck.create!(user: @user, channel: @channel, youtube_url: "https://www.youtube.com/watch?v=test_other1", status: :completed)
    claim2 = Claim.create!(fact_check: other_fc, verdict: :false_claim, claim_text: "주장 2")

    results = Claim.by_fact_check(@fact_check.id)
    assert_includes results, claim1
    assert_not_includes results, claim2
  end

  test "ordered 스코프는 timestamp_start 오름차순으로 정렬한다" do
    claim_later = Claim.create!(
      fact_check: @fact_check, verdict: :true_claim,
      claim_text: "나중 주장", timestamp_start: 60
    )
    claim_earlier = Claim.create!(
      fact_check: @fact_check, verdict: :false_claim,
      claim_text: "먼저 주장", timestamp_start: 10
    )

    results = Claim.ordered
    assert_equal claim_earlier, results.first
    assert_equal claim_later, results.last
  end

  # --- association 테스트 ---

  test "fact_check 연관이 존재한다" do
    claim = Claim.create!(fact_check: @fact_check, verdict: :unverified, claim_text: "테스트")
    assert_equal @fact_check, claim.fact_check
  end

  test "news_sources 연관이 존재한다" do
    claim = Claim.create!(fact_check: @fact_check, verdict: :unverified, claim_text: "테스트")
    assert_respond_to claim, :news_sources
  end
end
