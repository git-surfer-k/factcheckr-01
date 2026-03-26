# frozen_string_literal: true

# @TASK P4-S1-T1 - 내 기록 화면 UI 통합 테스트
# @SPEC specs/screens/b2c-history.yaml
# 내 팩트체크 기록 목록, 빈 상태, 리포트 이동 링크를 검증
require "test_helper"

class HistoryPageTest < ActionDispatch::IntegrationTest
  # 테스트 전에 사용자와 채널, 팩트체크 데이터를 생성한다
  def setup
    # 테스트용 사용자 생성 (이메일 중복 방지를 위해 랜덤 suffix 사용)
    @user = User.create!(
      email: "history_test_#{SecureRandom.hex(4)}@example.com",
      user_type: :b2c,
      is_active: true
    )

    # 테스트용 채널 생성
    @channel = Channel.create!(
      youtube_channel_id: "UC_history_test_#{SecureRandom.hex(4)}",
      name: "팩트체크채널",
      category: "정치",
      trust_score: 75,
      total_checks: 10
    )

    # 테스트용 팩트체크 기록 2개 생성
    @fact_check_1 = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=aaabbbccc01",
      video_title: "첫 번째 팩트체크 영상",
      video_thumbnail: "https://img.youtube.com/vi/aaabbbccc01/hqdefault.jpg",
      overall_score: 82,
      status: :completed
    )

    @fact_check_2 = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=aaabbbccc02",
      video_title: "두 번째 팩트체크 영상",
      video_thumbnail: nil,
      overall_score: 45,
      status: :completed
    )

    # 북마크 생성 (내 기록에 저장)
    Bookmark.create!(user: @user, fact_check: @fact_check_1)
    Bookmark.create!(user: @user, fact_check: @fact_check_2)

    # 세션 생성 (token은 before_create에서 자동 생성됨)
    @web_session = Session.create!(user: @user)
  end

  # 테스트 후 생성한 데이터를 삭제한다
  def teardown
    Bookmark.where(user: @user).delete_all
    FactCheck.where(user: @user).delete_all
    Session.where(user: @user).delete_all
    Channel.where(id: @channel.id).delete_all
    User.where(id: @user.id).delete_all
  end

  # 쿠키에 세션 토큰을 설정하여 로그인 상태를 시뮬레이션한다
  def login_with_session(web_session)
    cookies[:session_token] = web_session.token
  end

  # ===== 비로그인 사용자 테스트 =====

  # 로그인하지 않은 사용자는 홈으로 리다이렉트되어야 한다
  test "비로그인 사용자는 로그인 페이지로 리다이렉트된다" do
    get history_path
    assert_redirected_to auth_path
  end

  # ===== 기록 목록 표시 테스트 =====

  # 로그인한 사용자가 /history 접근 시 200 응답
  test "로그인한 사용자는 기록 페이지에 접근할 수 있다" do
    login_with_session(@web_session)
    get history_path
    assert_response :success
  end

  # 페이지 제목 "내 기록"이 표시되어야 한다
  test "페이지 제목이 표시된다" do
    login_with_session(@web_session)
    get history_path
    assert_select "h1", text: /내 기록/
  end

  # HistoryList 컴포넌트가 렌더링되어야 한다
  test "기록 목록 컴포넌트가 표시된다" do
    login_with_session(@web_session)
    get history_path
    assert_select "[data-component='history-list']"
  end

  # 팩트체크 영상 제목이 목록에 나타나야 한다
  test "팩트체크 영상 제목이 목록에 표시된다" do
    login_with_session(@web_session)
    get history_path
    assert_select "[data-component='history-list']" do
      assert_select "[data-history-title]", text: "첫 번째 팩트체크 영상"
      assert_select "[data-history-title]", text: "두 번째 팩트체크 영상"
    end
  end

  # 채널명이 각 항목에 표시되어야 한다
  test "채널명이 각 기록 항목에 표시된다" do
    login_with_session(@web_session)
    get history_path
    assert_select "[data-history-channel]", minimum: 1
  end

  # ScoreBadge(점수 배지)가 표시되어야 한다
  test "팩트체크 점수 배지가 표시된다" do
    login_with_session(@web_session)
    get history_path
    assert_select "[data-component='score-badge']", minimum: 1
  end

  # 리포트 상세 페이지로 이동하는 링크가 있어야 한다
  test "각 기록 항목이 리포트 상세 링크를 포함한다" do
    login_with_session(@web_session)
    get history_path
    assert_select "a[href*='/reports/']", minimum: 1
  end

  # ===== 빈 상태 테스트 =====

  # 기록이 없을 때 EmptyState 컴포넌트가 렌더링되어야 한다
  test "팩트체크 기록이 없으면 빈 상태 안내가 표시된다" do
    # 팩트체크 없는 새 사용자 생성
    empty_user = User.create!(
      email: "empty_history_#{SecureRandom.hex(4)}@example.com",
      user_type: :b2c,
      is_active: true
    )
    empty_session = Session.create!(user: empty_user)

    cookies[:session_token] = empty_session.token
    get history_path
    assert_select "[data-component='history-empty']"

    # 정리
    Session.where(user: empty_user).delete_all
    User.where(id: empty_user.id).delete_all
  end

  # 빈 상태일 때 홈으로 이동 CTA 버튼이 있어야 한다
  test "빈 상태에서 홈으로 이동 버튼이 표시된다" do
    empty_user = User.create!(
      email: "empty_cta_#{SecureRandom.hex(4)}@example.com",
      user_type: :b2c,
      is_active: true
    )
    empty_session = Session.create!(user: empty_user)

    cookies[:session_token] = empty_session.token
    get history_path
    assert_select "[data-component='history-empty'] a[href='/']"

    # 정리
    Session.where(user: empty_user).delete_all
    User.where(id: empty_user.id).delete_all
  end

  # ===== 상태(status) 표시 테스트 =====

  # analyzing 상태인 기록에는 상태 표시가 나타나야 한다
  test "분석 중인 팩트체크에 상태 표시가 나타난다" do
    analyzing_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=aaabbbccc03",
      video_title: "분석 중 영상",
      status: :analyzing
    )
    # 북마크도 생성해야 내 기록에 표시됨
    bookmark = Bookmark.create!(user: @user, fact_check: analyzing_check)

    login_with_session(@web_session)
    get history_path
    assert_select "[data-history-status]", minimum: 1

    bookmark.delete
    FactCheck.where(id: analyzing_check.id).delete_all
  end
end
