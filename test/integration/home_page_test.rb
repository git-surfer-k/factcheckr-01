# frozen_string_literal: true

# @TASK P2-S1-T1 - 홈 화면 UI 통합 테스트
# @SPEC specs/screens/b2c-home.yaml
# 홈 페이지의 URL 입력 폼, 최근 팩트체크 목록, 빈 상태를 검증
require "test_helper"

class HomePageTest < ActionDispatch::IntegrationTest
  # 홈 페이지가 정상 응답(200)을 반환하는지 확인
  test "홈 페이지가 정상적으로 로드된다" do
    get root_path
    assert_response :success
  end

  # URL 입력 폼이 페이지에 존재하는지 확인
  test "유튜브 URL 입력창이 표시된다" do
    get root_path
    assert_select "form[data-component='url-input']"
    assert_select "input[data-input='youtube-url']"
  end

  # 팩트체크 버튼이 존재하는지 확인
  test "팩트체크 버튼이 표시된다" do
    get root_path
    assert_select "button[data-action='submit-url']"
  end

  # 빈 상태일 때 안내 메시지가 표시되는지 확인 (로그인 없이 접근 시)
  test "팩트체크 이력이 없으면 빈 상태 안내 문구가 표시된다" do
    get root_path
    assert_select "[data-component='empty-state']"
  end

  # /analyze/:id 라우트가 존재하는지 확인
  test "분석 페이지 라우트가 존재한다" do
    assert_routing({ path: "/analyze/1", method: :get }, { controller: "pages", action: "analyze", id: "1" })
  end

  # /reports/:id 라우트가 존재하는지 확인
  test "리포트 상세 페이지 라우트가 존재한다" do
    assert_routing({ path: "/reports/1", method: :get }, { controller: "reports", action: "show", id: "1" })
  end

  # ScoreBadge가 올바른 색상 클래스를 갖는지 확인 (헬퍼 단위 테스트는 helper_test에서)
  test "홈 페이지에 최근 팩트체크 섹션이 표시된다" do
    get root_path
    assert_select "[data-component='recent-checks']"
  end
end
