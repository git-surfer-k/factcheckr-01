# frozen_string_literal: true

# @TASK P2-S2-T1 - 분석 로딩 화면 UI 통합 테스트
# @SPEC specs/screens/b2c-analyze.yaml
# 분석 진행 표시, 스텝퍼, 취소 버튼, 상태별 UI 요소를 검증한다.
require "test_helper"

class AnalyzePageTest < ActionDispatch::IntegrationTest
  # /analyze/:id 라우트가 존재하며 정상 응답(200)을 반환하는지 확인
  test "분석 페이지가 정상적으로 로드된다" do
    get analyze_path(id: "test-123")
    assert_response :success
  end

  # 분석 중 안내 문구가 표시되는지 확인
  test "AI 팩트체크 중 안내 문구가 표시된다" do
    get analyze_path(id: "test-456")
    assert_select "[data-component='analysis-progress']"
  end

  # 5단계 스텝퍼가 모두 표시되는지 확인
  test "5단계 분석 단계가 표시된다" do
    get analyze_path(id: "test-789")
    assert_select "[data-step]", count: 5
  end

  # 각 분석 단계의 이름이 올바르게 표시되는지 확인
  test "다운로드 단계가 표시된다" do
    get analyze_path(id: "test-abc")
    assert_select "[data-step='download']"
  end

  test "음성인식 단계가 표시된다" do
    get analyze_path(id: "test-abc")
    assert_select "[data-step='transcribe']"
  end

  test "주장추출 단계가 표시된다" do
    get analyze_path(id: "test-abc")
    assert_select "[data-step='extract']"
  end

  test "뉴스대조 단계가 표시된다" do
    get analyze_path(id: "test-abc")
    assert_select "[data-step='verify']"
  end

  test "리포트생성 단계가 표시된다" do
    get analyze_path(id: "test-abc")
    assert_select "[data-step='report']"
  end

  # 취소 버튼이 표시되는지 확인
  test "분석 취소 버튼이 표시된다" do
    get analyze_path(id: "test-cancel")
    assert_select "[data-action='cancel-analysis']"
  end

  # 상태 폴링을 위한 fact_check_id 데이터 속성이 존재하는지 확인
  test "fact_check_id가 data 속성으로 포함된다" do
    get analyze_path(id: "test-polling")
    assert_select "[data-fact-check-id]"
  end

  # 폴링 간격 데이터 속성이 존재하는지 확인
  test "폴링 설정 데이터 속성이 포함된다" do
    get analyze_path(id: "test-polling")
    assert_select "[data-poll-interval]"
  end

  # 에러 메시지 영역이 존재하는지 확인 (failed 상태에서 표시됨)
  test "에러 메시지 영역이 존재한다" do
    get analyze_path(id: "test-error")
    assert_select "[data-component='error-state']"
  end

  # 재시도 버튼 영역이 존재하는지 확인 (failed 상태에서 표시됨)
  test "재시도 버튼 영역이 존재한다" do
    get analyze_path(id: "test-retry")
    assert_select "[data-action='retry-analysis']"
  end

  # 페이지 타이틀이 올바르게 설정되는지 확인
  test "페이지 타이틀이 분석 중으로 설정된다" do
    get analyze_path(id: "test-title")
    assert_select "title", text: /분석 중/
  end
end
