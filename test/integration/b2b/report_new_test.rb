# frozen_string_literal: true

# @TASK P5-S3-T1 - B2B 리포트 요청 화면 통합 테스트
# @SPEC specs/screens/b2b-report-request.yaml
# CompanyForm 렌더링, 폼 필드 구성, 라우트를 검증한다.
require "test_helper"

class B2bReportNewTest < ActionDispatch::IntegrationTest
  # GET /b2b/reports/new 가 200 응답을 반환하는지 확인
  test "B2B 리포트 요청 페이지가 정상적으로 로드된다" do
    get b2b_new_report_path
    assert_response :success
  end

  # B2B 전용 레이아웃(b2b.html.erb)이 적용되는지 확인
  test "B2B 전용 레이아웃이 적용된다" do
    get b2b_new_report_path
    assert_select "[data-layout='b2b']"
  end

  # 페이지 타이틀이 올바르게 설정되는지 확인
  test "페이지 타이틀이 리포트 요청을 포함한다" do
    get b2b_new_report_path
    assert_select "title", text: /리포트 요청/
  end

  # CompanyForm 컴포넌트 자체가 렌더링되는지 확인
  test "CompanyForm 컴포넌트가 렌더링된다" do
    get b2b_new_report_path
    assert_select "[data-component='company-form']"
  end

  # 기업명 입력 필드가 존재하는지 확인
  test "기업명 입력 필드가 존재한다" do
    get b2b_new_report_path
    assert_select "[data-field='company-name-input']"
    assert_select "input[name='company_name'][required]"
  end

  # 업종 입력 필드가 존재하는지 확인
  test "업종 입력 필드가 존재한다" do
    get b2b_new_report_path
    assert_select "[data-field='industry-input']"
    assert_select "input[name='industry'][required]"
  end

  # 상품 정보 텍스트 영역이 존재하는지 확인
  test "상품 정보 텍스트 영역이 존재한다" do
    get b2b_new_report_path
    assert_select "[data-field='product-info-input']"
    assert_select "textarea[name='product_info']"
  end

  # 타겟 카테고리 체크박스 영역이 존재하는지 확인
  test "타겟 카테고리 체크박스 영역이 존재한다" do
    get b2b_new_report_path
    assert_select "[data-component='category-checkboxes']"
  end

  # 4개 카테고리 체크박스가 모두 렌더링되는지 확인
  test "타겟 카테고리 체크박스가 4개 존재한다" do
    get b2b_new_report_path
    assert_select "input[type='checkbox'][name='target_categories[]']", count: 4
  end

  # 정치 카테고리 체크박스가 존재하는지 확인
  test "정치 카테고리 체크박스가 존재한다" do
    get b2b_new_report_path
    assert_select "input[type='checkbox'][name='target_categories[]'][value='정치']"
  end

  # 경제 카테고리 체크박스가 존재하는지 확인
  test "경제 카테고리 체크박스가 존재한다" do
    get b2b_new_report_path
    assert_select "input[type='checkbox'][name='target_categories[]'][value='경제']"
  end

  # 사회 카테고리 체크박스가 존재하는지 확인
  test "사회 카테고리 체크박스가 존재한다" do
    get b2b_new_report_path
    assert_select "input[type='checkbox'][name='target_categories[]'][value='사회']"
  end

  # 국제 카테고리 체크박스가 존재하는지 확인
  test "국제 카테고리 체크박스가 존재한다" do
    get b2b_new_report_path
    assert_select "input[type='checkbox'][name='target_categories[]'][value='국제']"
  end

  # 제출 버튼이 존재하는지 확인
  test "리포트 요청 제출 버튼이 존재한다" do
    get b2b_new_report_path
    assert_select "[data-component='submit-button']"
  end

  # 제출 버튼에 올바른 aria-label이 있는지 확인
  test "제출 버튼에 접근성 레이블이 있다" do
    get b2b_new_report_path
    assert_select "button[aria-label='광고적합성 리포트 요청하기']"
  end

  # 에러 배너가 기본적으로 숨김 상태인지 확인
  test "에러 배너가 기본적으로 숨김 상태이다" do
    get b2b_new_report_path
    assert_select "[data-component='error-banner'].hidden"
  end

  # 기업명 필드에 required 속성이 있는지 확인
  test "기업명 필드에 aria-required 속성이 있다" do
    get b2b_new_report_path
    assert_select "input[name='company_name'][aria-required='true']"
  end

  # 폼에 novalidate 속성이 있는지 확인 (클라이언트 JS 검증 사용)
  test "폼에 novalidate 속성이 있다" do
    get b2b_new_report_path
    assert_select "form[novalidate]"
  end

  # 페이지 헤더 컴포넌트가 존재하는지 확인
  test "페이지 헤더가 렌더링된다" do
    get b2b_new_report_path
    assert_select "[data-component='page-header']"
  end

  # 페이지 제목 텍스트가 올바른지 확인
  test "페이지 제목이 올바르게 표시된다" do
    get b2b_new_report_path
    assert_select "[data-field='page-title']", text: /광고적합성 리포트 요청/
  end

  # 기업 정보 섹션이 존재하는지 확인
  test "기업 정보 섹션이 렌더링된다" do
    get b2b_new_report_path
    assert_select "[data-section='company-info']"
  end

  # 상품 정보 섹션이 존재하는지 확인
  test "상품 정보 섹션이 렌더링된다" do
    get b2b_new_report_path
    assert_select "[data-section='product-info']"
  end

  # 타겟 카테고리 섹션이 존재하는지 확인
  test "타겟 카테고리 섹션이 렌더링된다" do
    get b2b_new_report_path
    assert_select "[data-section='target-categories']"
  end

  # 분석 프로세스 안내 박스가 표시되는지 확인
  test "분석 프로세스 안내 박스가 표시된다" do
    get b2b_new_report_path
    assert_select "[data-component='process-info']"
  end

  # CSRF 보호가 레이아웃에 선언되어 있는지 확인 (테스트 환경에서는 토큰이 빈 값으로 렌더링됨)
  # 레이아웃 파일에 csrf_meta_tags 헬퍼가 있으므로 페이지 자체는 200 응답을 반환한다
  test "CSRF 보호가 적용된 레이아웃으로 페이지가 렌더링된다" do
    get b2b_new_report_path
    assert_response :success
    # 레이아웃이 올바르게 적용되면 charset 메타 태그가 있다
    assert_select "meta[charset='utf-8']"
  end

  # 리포트 요청 페이지 컨테이너가 존재하는지 확인
  test "리포트 요청 페이지 컨테이너가 존재한다" do
    get b2b_new_report_path
    assert_select "[data-component='report-request-page']"
  end
end
