# frozen_string_literal: true

# @TASK P5-S4-T1 - B2B 리포트 상세 화면 통합 테스트
# @SPEC specs/screens/b2b-report-detail.yaml
# B2B 리포트 상세 페이지 렌더링, 컴포넌트 구성, 인증을 검증한다.
require "test_helper"

class B2bReportDetailTest < ActionDispatch::IntegrationTest
  def setup
    # 테스트용 B2B 사용자 생성
    @user = User.create!(
      email: "b2b_test_#{SecureRandom.hex(4)}@example.com",
      user_type: :b2b,
      is_active: true
    )

    # 테스트용 세션 생성 (B2B 로그인 상태 시뮬레이션)
    @db_session = @user.create_session!

    # completed 상태의 리포트 생성 (추천 채널 + 리포트 본문 포함)
    @report = B2bReport.create!(
      user: @user,
      company_name: "테스트 기업",
      industry: "IT/소프트웨어",
      product_info: "B2B SaaS 솔루션",
      target_categories: "기술, 비즈니스",
      status: :completed,
      recommended_channels: [
        { "channel_name" => "테크뉴스채널", "trust_score" => 85, "fit_score" => 92, "category" => "기술" },
        { "channel_name" => "비즈뉴스", "trust_score" => 78, "fit_score" => 88, "category" => "비즈니스" }
      ].to_json,
      report_data: {
        "summary" => "광고 집행에 적합한 채널입니다.",
        "risk_level" => "low",
        "total_channels_analyzed" => 50
      }.to_json
    )

    # pending 상태의 리포트 생성 (분석 미완료)
    @pending_report = B2bReport.create!(
      user: @user,
      company_name: "대기 기업",
      industry: "제조",
      status: :pending
    )

    # 다른 사용자 소유의 리포트 (접근 불가)
    @other_user = User.create!(
      email: "other_#{SecureRandom.hex(4)}@example.com",
      user_type: :b2b,
      is_active: true
    )
    @other_report = B2bReport.create!(
      user: @other_user,
      company_name: "타기업",
      industry: "유통",
      status: :completed
    )
  end

  def teardown
    # 테스트 데이터 정리
    @other_report.destroy
    @other_user.destroy
    @pending_report.destroy
    @report.destroy
    @db_session.destroy
    @user.destroy
  end

  # 세션 쿠키를 설정하여 로그인 상태를 시뮬레이션하는 헬퍼
  def login_as(session_record)
    cookies[:b2b_session_token] = session_record.token
  end

  # ----- 라우트 검증 -----

  # B2B 리포트 상세 라우트가 올바르게 매핑되는지 확인
  test "B2B 리포트 상세 라우트가 올바르게 매핑된다" do
    assert_routing(
      { path: "/b2b/reports/#{@report.id}", method: :get },
      { controller: "b2b/reports", action: "show", id: @report.id.to_s }
    )
  end

  # ----- 인증 검증 -----

  # 비로그인 상태에서 리포트 상세에 접근하면 로그인 페이지로 리다이렉트
  test "비로그인 사용자는 리포트 상세에 접근할 수 없다" do
    get b2b_report_path(@report)
    assert_response :redirect
    assert_redirected_to b2b_login_path
  end

  # 다른 사용자의 리포트는 접근 불가 (404)
  test "다른 사용자의 리포트는 접근할 수 없다" do
    login_as(@db_session)
    get b2b_report_path(@other_report)
    assert_response :not_found
  end

  # ----- 페이지 렌더링 검증 -----

  # 완료된 리포트 상세 페이지가 200 응답을 반환하는지 확인
  test "완료된 리포트 상세 페이지가 정상적으로 로드된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_response :success
  end

  # B2B 레이아웃이 적용되는지 확인
  test "B2B 전용 레이아웃이 적용된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-layout='b2b']"
  end

  # ----- ReportHeader 컴포넌트 검증 -----

  # 리포트 헤더 컴포넌트가 표시되는지 확인
  test "ReportHeader 컴포넌트가 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-component='report-header']"
  end

  # 기업명이 표시되는지 확인
  test "기업명이 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-field='company-name']", text: /테스트 기업/
  end

  # 산업 분야가 표시되는지 확인
  test "산업 분야가 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-field='industry']", text: /IT\/소프트웨어/
  end

  # ----- StatusBadge 컴포넌트 검증 -----

  # 상태 배지 컴포넌트가 표시되는지 확인
  test "StatusBadge 컴포넌트가 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-component='status-badge']"
  end

  # completed 상태 배지가 올바르게 표시되는지 확인
  test "completed 상태 배지가 올바르게 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-component='status-badge'][data-status='completed']"
  end

  # pending 상태 배지가 올바르게 표시되는지 확인
  test "pending 상태 배지가 올바르게 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@pending_report)
    assert_select "[data-component='status-badge'][data-status='pending']"
  end

  # ----- RecommendedChannels 컴포넌트 검증 -----

  # 추천 채널 목록 컴포넌트가 표시되는지 확인 (완료된 리포트)
  test "RecommendedChannels 컴포넌트가 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-component='recommended-channels']"
  end

  # 추천 채널 목록에 채널 항목이 표시되는지 확인
  test "추천 채널 항목이 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-component='channel-item']"
  end

  # 분석 미완료 리포트에서는 추천 채널 대신 안내 메시지 표시
  test "분석 중인 리포트에는 안내 메시지가 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@pending_report)
    assert_select "[data-component='analyzing-message']"
  end

  # ----- ReportContent 컴포넌트 검증 -----

  # 리포트 본문 컴포넌트가 표시되는지 확인 (완료된 리포트)
  test "ReportContent 컴포넌트가 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-component='report-content']"
  end

  # ----- 생성일 검증 -----

  # 생성일이 표시되는지 확인
  test "생성일이 표시된다" do
    login_as(@db_session)
    get b2b_report_path(@report)
    assert_select "[data-field='created-at']"
  end
end
