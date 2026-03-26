# frozen_string_literal: true

# @TASK P5-R1-T1 - B2bReport 모델 테스트
# @TEST test/models/b2b_report_test.rb
require "test_helper"

class B2bReportTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "b2b_model_test@example.com", user_type: :b2b)
    @report = B2bReport.create!(
      user: @user,
      company_name: "테스트 기업",
      industry: "IT/소프트웨어",
      product_info: "테스트 제품",
      target_categories: "시사,정치",
      status: :pending
    )
  end

  # --- 연관 관계 ---

  test "user 연관 관계가 존재한다" do
    assert_respond_to @report, :user
    assert_equal @user, @report.user
  end

  # --- 유효성 검사 ---

  test "user_id가 없으면 유효하지 않다" do
    report = B2bReport.new(company_name: "기업", industry: "IT")
    assert_not report.valid?
  end

  test "company_name이 없으면 유효하지 않다" do
    report = B2bReport.new(user: @user, industry: "IT")
    assert_not report.valid?
    assert_includes report.errors[:company_name], "can't be blank"
  end

  test "industry가 없으면 유효하지 않다" do
    report = B2bReport.new(user: @user, company_name: "기업")
    assert_not report.valid?
    assert_includes report.errors[:industry], "can't be blank"
  end

  test "company_name과 industry가 있으면 유효하다" do
    report = B2bReport.new(user: @user, company_name: "기업", industry: "IT")
    assert report.valid?
  end

  # --- Enum ---

  test "status enum 값이 올바르게 설정된다" do
    assert @report.pending?

    @report.status = :analyzing
    assert @report.analyzing?

    @report.status = :completed
    assert @report.completed?

    @report.status = :failed
    assert @report.failed?
  end

  test "status 기본값은 pending이다" do
    report = B2bReport.create!(
      user: @user,
      company_name: "기본값 테스트",
      industry: "제조"
    )
    assert report.pending?
  end

  # --- Scope ---

  test "recent 스코프는 최신 순으로 정렬한다" do
    older_report = B2bReport.create!(
      user: @user,
      company_name: "오래된 기업",
      industry: "건설",
      created_at: 3.days.ago
    )

    reports = B2bReport.recent
    assert_equal @report, reports.first
  end

  test "by_status 스코프는 특정 상태의 리포트만 반환한다" do
    completed_report = B2bReport.create!(
      user: @user,
      company_name: "완료된 기업",
      industry: "유통",
      status: :completed
    )

    pending_reports = B2bReport.by_status(:pending)
    assert_includes pending_reports, @report
    assert_not_includes pending_reports, completed_report

    completed_reports = B2bReport.by_status(:completed)
    assert_includes completed_reports, completed_report
    assert_not_includes completed_reports, @report
  end

  test "by_user 스코프는 특정 사용자의 리포트만 반환한다" do
    other_user = User.create!(email: "other_b2b_model@example.com", user_type: :b2b)
    other_report = B2bReport.create!(
      user: other_user,
      company_name: "다른 기업",
      industry: "교육"
    )

    user_reports = B2bReport.by_user(@user.id)
    assert_includes user_reports, @report
    assert_not_includes user_reports, other_report
  end
end
