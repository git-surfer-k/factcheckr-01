# frozen_string_literal: true

# @TASK P2-R3-T1 - NewsSource 모델 테스트
# @TEST test/models/news_source_test.rb
require "test_helper"

class NewsSourceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com", user_type: :b2c)
    @channel = Channel.create!(youtube_channel_id: "UC_test_123", name: "테스트 채널")
    @fact_check = FactCheck.create!(
      user: @user, channel: @channel, status: :completed,
      youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    )
    @claim = Claim.create!(fact_check: @fact_check, verdict: :true_claim)
    @news_source = NewsSource.create!(
      claim: @claim,
      title: "테스트 뉴스 기사",
      url: "https://example.com/news/1",
      publisher: "테스트 신문사",
      author: "홍길동",
      published_at: 1.day.ago,
      relevance_score: 0.85,
      bigkinds_doc_id: "BK_DOC_001"
    )
  end

  # --- 연관 관계 ---

  test "claim 연관 관계가 존재한다" do
    assert_respond_to @news_source, :claim
    assert_equal @claim, @news_source.claim
  end

  # --- 유효성 검사 ---

  test "claim_id가 없으면 유효하지 않다" do
    news_source = NewsSource.new(title: "기사", url: "https://example.com")
    assert_not news_source.valid?
    assert_includes news_source.errors[:claim_id], "can't be blank"
  end

  test "title이 없으면 유효하지 않다" do
    news_source = NewsSource.new(claim: @claim, url: "https://example.com")
    assert_not news_source.valid?
    assert_includes news_source.errors[:title], "can't be blank"
  end

  test "url이 없으면 유효하지 않다" do
    news_source = NewsSource.new(claim: @claim, title: "기사 제목")
    assert_not news_source.valid?
    assert_includes news_source.errors[:url], "can't be blank"
  end

  test "title과 url이 있으면 유효하다" do
    news_source = NewsSource.new(
      claim: @claim,
      title: "유효한 기사",
      url: "https://example.com/valid"
    )
    assert news_source.valid?
  end

  # --- Scope ---

  test "by_claim 스코프는 특정 주장의 뉴스만 반환한다" do
    other_claim = Claim.create!(fact_check: @fact_check, verdict: :false_claim)
    other_news = NewsSource.create!(
      claim: other_claim,
      title: "다른 기사",
      url: "https://example.com/other"
    )

    claim_news = NewsSource.by_claim(@claim.id)
    assert_includes claim_news, @news_source
    assert_not_includes claim_news, other_news
  end

  test "by_relevance 스코프는 relevance_score 내림차순으로 정렬한다" do
    high_relevance = NewsSource.create!(
      claim: @claim,
      title: "높은 관련도 기사",
      url: "https://example.com/high",
      relevance_score: 0.95
    )
    low_relevance = NewsSource.create!(
      claim: @claim,
      title: "낮은 관련도 기사",
      url: "https://example.com/low",
      relevance_score: 0.3
    )

    sorted = NewsSource.by_relevance
    scores = sorted.pluck(:relevance_score)
    assert_equal scores, scores.sort.reverse
  end

  test "highly_relevant 스코프는 relevance_score 0.7 이상만 반환한다" do
    low_relevance = NewsSource.create!(
      claim: @claim,
      title: "낮은 관련도 기사",
      url: "https://example.com/low",
      relevance_score: 0.3
    )

    relevant = NewsSource.highly_relevant
    assert_includes relevant, @news_source  # 0.85
    assert_not_includes relevant, low_relevance  # 0.3
  end

  test "recent 스코프는 published_at 내림차순으로 정렬한다" do
    old_news = NewsSource.create!(
      claim: @claim,
      title: "오래된 기사",
      url: "https://example.com/old",
      published_at: 30.days.ago
    )

    recent = NewsSource.recent
    assert_equal @news_source, recent.first
  end
end
