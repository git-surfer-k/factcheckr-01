# frozen_string_literal: true

# @TASK P5-R1-T1 - B2B Reports API 컨트롤러 테스트
# @TEST test/controllers/api/v1/b2b/reports_controller_test.rb
# POST /api/v1/b2b/reports, GET /api/v1/b2b/reports/:id, GET /api/v1/b2b/reports
require "test_helper"

class Api::V1::B2b::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # B2B 사용자 생성
    @b2b_user = User.create!(
      email: "b2b_company@example.com",
      name: "B2B 기업 사용자",
      user_type: :b2b
    )
    @b2b_session = @b2b_user.create_session!
    @b2b_headers = { "X-Session-Token" => @b2b_session.token }

    # B2C 사용자 생성 (접근 거부 테스트용)
    @b2c_user = User.create!(
      email: "b2c_user@example.com",
      name: "일반 사용자",
      user_type: :b2c
    )
    @b2c_session = @b2c_user.create_session!
    @b2c_headers = { "X-Session-Token" => @b2c_session.token }

    # 기존 리포트 생성
    @report = B2bReport.create!(
      user: @b2b_user,
      company_name: "테스트 주식회사",
      industry: "IT/소프트웨어",
      product_info: "AI 팩트체크 플랫폼",
      target_categories: "시사,정치,경제",
      status: :completed,
      completed_at: Time.current
    )
  end

  # === POST /api/v1/b2b/reports ===

  test "create: 유효한 파라미터로 리포트를 생성한다" do
    assert_difference("B2bReport.count", 1) do
      post "/api/v1/b2b/reports",
        params: {
          company_name: "새로운 기업",
          industry: "제조업",
          product_info: "스마트 공장 솔루션",
          target_categories: "기술,제조"
        },
        headers: @b2b_headers,
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "pending", json["status"]
    assert_equal "새로운 기업", json["company_name"]
    assert_equal "제조업", json["industry"]
    assert_not_nil json["id"]
    assert_not_nil json["created_at"]
  end

  test "create: company_name이 없으면 422 에러" do
    assert_no_difference("B2bReport.count") do
      post "/api/v1/b2b/reports",
        params: {
          industry: "제조업"
        },
        headers: @b2b_headers,
        as: :json
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "create: industry가 없으면 422 에러" do
    assert_no_difference("B2bReport.count") do
      post "/api/v1/b2b/reports",
        params: {
          company_name: "테스트 기업"
        },
        headers: @b2b_headers,
        as: :json
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "create: B2C 사용자는 접근할 수 없다 (403)" do
    assert_no_difference("B2bReport.count") do
      post "/api/v1/b2b/reports",
        params: {
          company_name: "기업",
          industry: "IT"
        },
        headers: @b2c_headers,
        as: :json
    end

    assert_response :forbidden
    json = JSON.parse(response.body)
    assert json["detail"].present?
  end

  test "create: 인증 없이 요청하면 401 에러" do
    post "/api/v1/b2b/reports",
      params: { company_name: "기업", industry: "IT" },
      as: :json

    assert_response :unauthorized
  end

  test "create: product_info와 target_categories는 선택 사항이다" do
    assert_difference("B2bReport.count", 1) do
      post "/api/v1/b2b/reports",
        params: {
          company_name: "최소 입력 기업",
          industry: "금융"
        },
        headers: @b2b_headers,
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "최소 입력 기업", json["company_name"]
    assert_equal "금융", json["industry"]
  end

  test "create: 응답에 필수 필드가 포함된다" do
    post "/api/v1/b2b/reports",
      params: {
        company_name: "필드 테스트 기업",
        industry: "미디어"
      },
      headers: @b2b_headers,
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    expected_fields = %w[id user_id company_name industry status created_at]
    expected_fields.each do |field|
      assert json.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  # === GET /api/v1/b2b/reports/:id ===

  test "show: 리포트 상세 정보를 반환한다" do
    get "/api/v1/b2b/reports/#{@report.id}",
      headers: @b2b_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @report.id, json["id"]
    assert_equal "completed", json["status"]
    assert_equal "테스트 주식회사", json["company_name"]
    assert_equal "IT/소프트웨어", json["industry"]
    assert_equal "AI 팩트체크 플랫폼", json["product_info"]
  end

  test "show: 다른 사용자의 리포트는 조회할 수 없다" do
    other_b2b_user = User.create!(email: "other_b2b@example.com", user_type: :b2b)
    other_report = B2bReport.create!(
      user: other_b2b_user,
      company_name: "다른 기업",
      industry: "유통"
    )

    get "/api/v1/b2b/reports/#{other_report.id}",
      headers: @b2b_headers,
      as: :json

    assert_response :not_found
  end

  test "show: 존재하지 않는 ID로 조회하면 404 에러" do
    get "/api/v1/b2b/reports/nonexistent-uuid-value",
      headers: @b2b_headers,
      as: :json

    assert_response :not_found
  end

  test "show: B2C 사용자는 접근할 수 없다 (403)" do
    get "/api/v1/b2b/reports/#{@report.id}",
      headers: @b2c_headers,
      as: :json

    assert_response :forbidden
  end

  test "show: 인증 없이 요청하면 401 에러" do
    get "/api/v1/b2b/reports/#{@report.id}", as: :json

    assert_response :unauthorized
  end

  test "show: 응답에 상세 필드가 포함된다" do
    get "/api/v1/b2b/reports/#{@report.id}",
      headers: @b2b_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    expected_fields = %w[id user_id company_name industry product_info
                         target_categories recommended_channels report_data
                         status completed_at created_at updated_at]
    expected_fields.each do |field|
      assert json.key?(field), "응답에 '#{field}' 필드가 누락되었습니다"
    end
  end

  # === GET /api/v1/b2b/reports ===

  test "index: 현재 사용자의 리포트 목록을 반환한다" do
    get "/api/v1/b2b/reports",
      headers: @b2b_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert json.key?("reports")
    assert json.key?("meta")
    assert_equal 1, json["reports"].length
  end

  test "index: 다른 사용자의 리포트는 포함하지 않는다" do
    other_b2b_user = User.create!(email: "another_b2b@example.com", user_type: :b2b)
    B2bReport.create!(
      user: other_b2b_user,
      company_name: "다른 회사",
      industry: "식품"
    )

    get "/api/v1/b2b/reports",
      headers: @b2b_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    # 다른 사용자의 리포트는 포함되지 않으므로 1개만
    assert_equal 1, json["reports"].length
  end

  test "index: 최신 순으로 정렬된다" do
    older_report = B2bReport.create!(
      user: @b2b_user,
      company_name: "오래된 기업",
      industry: "건설",
      created_at: 3.days.ago
    )

    get "/api/v1/b2b/reports",
      headers: @b2b_headers,
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    ids = json["reports"].map { |r| r["id"] }
    assert_equal @report.id, ids.first
  end

  test "index: 페이지네이션이 동작한다" do
    # 기존 1개 + 추가 10개 = 총 11개
    10.times do |i|
      B2bReport.create!(
        user: @b2b_user,
        company_name: "기업 #{i}",
        industry: "업종 #{i}"
      )
    end

    # 첫 페이지 (기본 per_page=10)
    get "/api/v1/b2b/reports", params: { page: 1 },
      headers: @b2b_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 10, json["reports"].length
    assert_equal 11, json["meta"]["total_count"]
    assert_equal 1, json["meta"]["current_page"]
    assert_equal 2, json["meta"]["total_pages"]

    # 두 번째 페이지
    get "/api/v1/b2b/reports", params: { page: 2 },
      headers: @b2b_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json["reports"].length
    assert_equal 2, json["meta"]["current_page"]
  end

  test "index: status 필터가 동작한다" do
    B2bReport.create!(
      user: @b2b_user,
      company_name: "대기 중 기업",
      industry: "교육",
      status: :pending
    )

    get "/api/v1/b2b/reports", params: { status: "completed" },
      headers: @b2b_headers, as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    json["reports"].each do |report|
      assert_equal "completed", report["status"]
    end
  end

  test "index: B2C 사용자는 접근할 수 없다 (403)" do
    get "/api/v1/b2b/reports",
      headers: @b2c_headers,
      as: :json

    assert_response :forbidden
  end

  test "index: 인증 없이 요청하면 401 에러" do
    get "/api/v1/b2b/reports", as: :json

    assert_response :unauthorized
  end
end
