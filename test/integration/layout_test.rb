# frozen_string_literal: true

# @TASK P1-S0-T1 - 공통 레이아웃 UI 테스트
# @TASK P4-S1-T1, P4-S2-T1 - 내기록/설정 페이지 인증 적용 후 테스트 업데이트
# 웹 상단 네비게이션과 모바일 하단 탭이 올바르게 렌더링되는지 확인
require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  # 홈 페이지가 정상적으로 응답하는지 확인
  test "홈 페이지 접근 가능" do
    get root_path
    assert_response :success
  end

  # 랭킹 페이지가 정상적으로 응답하는지 확인
  test "랭킹 페이지 접근 가능" do
    get ranking_path
    assert_response :success
  end

  # 내기록 페이지: 인증 필수이므로 로그인 상태에서 확인
  # 병렬 테스트 충돌 방지를 위해 랜덤 이메일 사용
  test "내기록 페이지 접근 가능" do
    user = User.create!(email: "layout_history_#{SecureRandom.hex(4)}@example.com", user_type: :b2c, is_active: true)
    web_session = Session.create!(user: user)
    cookies[:session_token] = web_session.token

    get history_path
    assert_response :success

    Session.where(user: user).delete_all
    User.where(id: user.id).delete_all
  end

  # 설정 페이지: 인증 필수이므로 로그인 상태에서 확인
  # 병렬 테스트 충돌 방지를 위해 랜덤 이메일 사용
  test "설정 페이지 접근 가능" do
    user = User.create!(email: "layout_settings_#{SecureRandom.hex(4)}@example.com", user_type: :b2c, is_active: true)
    web_session = Session.create!(user: user)
    cookies[:session_token] = web_session.token

    get settings_path
    assert_response :success

    Session.where(user: user).delete_all
    User.where(id: user.id).delete_all
  end

  # 레이아웃에 로고가 포함되어 있는지 확인
  test "레이아웃에 Factis 로고가 있다" do
    get root_path
    assert_select "a", text: /Factis/
  end

  # 웹 상단 네비게이션에 메뉴 항목이 있는지 확인
  test "웹 상단 네비게이션에 홈 메뉴가 있다" do
    get root_path
    assert_select "nav[data-nav='web-top']" do
      assert_select "a[href='/']"
    end
  end

  # 모바일 하단 탭에 홈 버튼이 있는지 확인
  test "모바일 하단 탭에 홈 탭이 있다" do
    get root_path
    assert_select "nav[data-nav='mobile-bottom']" do
      assert_select "a[href='/']"
    end
  end

  # 모바일 하단 탭에 랭킹 버튼이 있는지 확인
  test "모바일 하단 탭에 랭킹 탭이 있다" do
    get root_path
    assert_select "nav[data-nav='mobile-bottom']" do
      assert_select "a[href='/ranking']"
    end
  end

  # 모바일 하단 탭에 내기록 버튼이 있는지 확인
  test "모바일 하단 탭에 내기록 탭이 있다" do
    get root_path
    assert_select "nav[data-nav='mobile-bottom']" do
      assert_select "a[href='/history']"
    end
  end

  # 모바일 하단 탭에 설정 버튼이 있는지 확인
  test "모바일 하단 탭에 설정 탭이 있다" do
    get root_path
    assert_select "nav[data-nav='mobile-bottom']" do
      assert_select "a[href='/settings']"
    end
  end
end
