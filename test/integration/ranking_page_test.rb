# frozen_string_literal: true

# @TASK P3-S2-T1 - 채널 랭킹 화면 UI 통합 테스트
# @SPEC specs/screens/b2c-ranking.yaml
# 카테고리 탭, 랭킹 목록, 채널 상세 이동 링크를 검증
require "test_helper"

class RankingPageTest < ActionDispatch::IntegrationTest
  # 테스트용 채널 데이터를 미리 생성해두는 메서드
  def setup
    # 정치 카테고리 채널 (신뢰도 높음)
    @channel_politics = Channel.create!(
      youtube_channel_id: "UC_politics_001",
      name: "팩트뉴스",
      category: "정치",
      trust_score: 92,
      total_checks: 42,
      thumbnail_url: nil
    )

    # 경제 카테고리 채널 (신뢰도 보통)
    @channel_economy = Channel.create!(
      youtube_channel_id: "UC_economy_001",
      name: "시사인사이드",
      category: "경제",
      trust_score: 38,
      total_checks: 28,
      thumbnail_url: nil
    )
  end

  # 테스트 후 생성한 데이터를 삭제한다
  def teardown
    Channel.delete_all
  end

  # ===== 초기 로드 테스트 =====

  # 랭킹 페이지가 정상 응답(200)을 반환하는지 확인
  test "랭킹 페이지가 정상적으로 로드된다" do
    get ranking_path
    assert_response :success
  end

  # 페이지 제목이 올바르게 표시되는지 확인
  test "페이지 제목이 올바르게 표시된다" do
    get ranking_path
    assert_select "h1", text: /채널 랭킹/
  end

  # 카테고리 탭이 모두 표시되는지 확인
  test "카테고리 탭이 표시된다" do
    get ranking_path
    assert_select "[data-component='category-tabs']"
    assert_select "a", text: "전체"
    assert_select "a", text: "정치"
    assert_select "a", text: "경제"
    assert_select "a", text: "사회"
    assert_select "a", text: "국제"
  end

  # 전체 채널 랭킹 목록이 표시되는지 확인
  test "전체 카테고리 랭킹 목록이 표시된다" do
    get ranking_path
    assert_select "[data-component='ranking-list']"
    assert_select "[data-component='ranking-item']", minimum: 1
  end

  # 채널명이 목록에 나타나는지 확인
  test "채널명이 랭킹 목록에 표시된다" do
    get ranking_path
    assert_select "[data-component='ranking-list']" do
      assert_select "[data-channel-name]", text: "팩트뉴스"
      assert_select "[data-channel-name]", text: "시사인사이드"
    end
  end

  # ===== 카테고리 필터링 테스트 =====

  # 카테고리 파라미터로 필터링이 되는지 확인
  test "정치 카테고리 탭 클릭 시 정치 채널만 표시된다" do
    get ranking_path, params: { category: "정치" }
    assert_response :success
    assert_select "[data-channel-name]", text: "팩트뉴스"
    assert_select "[data-channel-name]", text: "시사인사이드", count: 0
  end

  # 경제 카테고리 필터링 확인
  test "경제 카테고리 탭 클릭 시 경제 채널만 표시된다" do
    get ranking_path, params: { category: "경제" }
    assert_response :success
    assert_select "[data-channel-name]", text: "시사인사이드"
    assert_select "[data-channel-name]", text: "팩트뉴스", count: 0
  end

  # 활성 탭이 올바르게 표시되는지 확인
  test "선택한 카테고리 탭이 활성 상태로 표시된다" do
    get ranking_path, params: { category: "정치" }
    assert_select "[data-tab-active='true']", text: "정치"
  end

  # 전체 탭이 카테고리 없을 때 활성 상태인지 확인
  test "카테고리 파라미터 없을 때 전체 탭이 활성 상태이다" do
    get ranking_path
    assert_select "[data-tab-active='true']", text: "전체"
  end

  # ===== ScoreBadge 테스트 =====

  # 신뢰도 점수가 배지로 표시되는지 확인
  test "채널 신뢰도 점수가 ScoreBadge로 표시된다" do
    get ranking_path
    assert_select "[data-component='score-badge']", minimum: 1
  end

  # 총 검증 수가 표시되는지 확인
  test "채널 총 검증 수가 표시된다" do
    get ranking_path
    assert_select "[data-channel-checks]", minimum: 1
  end

  # ===== 채널 상세 이동 링크 테스트 =====

  # 채널 클릭 시 상세 페이지로 이동하는 링크가 있는지 확인
  test "랭킹 목록 채널 항목이 채널 상세 링크를 포함한다" do
    get ranking_path
    # /channels/:id 형식의 링크가 존재하는지 확인
    assert_select "a[href*='/channels/']", minimum: 1
  end

  # 순위 번호가 표시되는지 확인
  test "채널 순위 번호가 표시된다" do
    get ranking_path
    assert_select "[data-channel-rank]", minimum: 1
  end

  # ===== 빈 상태 테스트 =====

  # 해당 카테고리에 채널이 없을 때 빈 상태 메시지 표시 확인
  test "해당 카테고리에 채널이 없으면 빈 상태 안내 문구가 표시된다" do
    get ranking_path, params: { category: "사회" }
    assert_response :success
    assert_select "[data-component='ranking-empty']"
  end
end
