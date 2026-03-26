# frozen_string_literal: true

# @TASK P2-S4-T1 - 다운로드 모달 UI 통합 테스트
# @SPEC specs/screens/b2c-report-detail.yaml
# 다운로드 모달 컴포넌트와 SubscriptionNotice의 HTML 구조를 검증한다.
require "test_helper"

class DownloadModalTest < ActionDispatch::IntegrationTest
  # 테스트용 픽스처 데이터를 사전에 준비한다.
  setup do
    @channel = Channel.create!(
      youtube_channel_id: "UC_test_download_ch",
      name: "테스트 채널",
      description: "다운로드 모달 테스트용",
      subscriber_count: 100_000,
      trust_score: 75.0,
      total_checks: 5,
      thumbnail_url: nil
    )

    @user = User.create!(
      email: "download_test@example.com",
      name: "다운로드 테스터",
      user_type: 0,
      is_active: true
    )

    @fact_check = FactCheck.create!(
      user: @user,
      channel: @channel,
      youtube_url: "https://www.youtube.com/watch?v=test_download_01",
      video_title: "다운로드 테스트 영상",
      summary: "테스트 요약입니다.",
      overall_score: 75.0,
      analysis_detail: "테스트 분석 내용",
      status: :completed,
      completed_at: Time.current
    )
  end

  # ----- 다운로드 버튼 -----

  # 다운로드 버튼이 리포트 헤더에 표시되는지 확인
  test "다운로드 버튼이 표시된다" do
    get report_path(@fact_check.id)
    assert_response :success
    assert_select "[data-component='download-button']"
  end

  # 다운로드 버튼이 모달을 열도록 data 속성이 존재하는지 확인
  test "다운로드 버튼에 모달 트리거 속성이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-button'][data-modal-target='download-modal']"
  end

  # ----- 다운로드 모달 구조 -----

  # 다운로드 모달 컨테이너가 페이지에 존재하는지 확인
  test "다운로드 모달 컨테이너가 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']"
  end

  # 모달이 기본으로 숨겨져 있는지 확인 (hidden 클래스 또는 aria-hidden)
  test "다운로드 모달이 기본으로 숨겨져 있다" do
    get report_path(@fact_check.id)
    # hidden 클래스를 갖거나 hidden 속성이 있어야 한다
    assert_select "[data-component='download-modal'].hidden"
  end

  # 모달 닫기 버튼이 존재하는지 확인
  test "모달 닫기 버튼이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']" do
      assert_select "[data-action='close-modal']"
    end
  end

  # 모달 제목이 표시되는지 확인
  test "모달 제목이 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']" do
      assert_select "[data-field='modal-title']"
    end
  end

  # ----- 형식 선택 (무료/유료 공통) -----

  # PDF 형식 선택 옵션이 존재하는지 확인
  test "PDF 형식 선택 옵션이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']" do
      assert_select "[data-format='pdf']"
    end
  end

  # MD 형식 선택 옵션이 존재하는지 확인
  test "MD 형식 선택 옵션이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']" do
      assert_select "[data-format='md']"
    end
  end

  # DOCX 형식 선택 옵션이 존재하는지 확인
  test "DOCX 형식 선택 옵션이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']" do
      assert_select "[data-format='docx']"
    end
  end

  # HWP 형식 선택 옵션이 존재하는지 확인
  test "HWP 형식 선택 옵션이 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']" do
      assert_select "[data-format='hwp']"
    end
  end

  # ----- SubscriptionNotice (무료 사용자 안내) -----

  # 구독 안내 컴포넌트가 모달 내에 존재하는지 확인
  test "구독 필요 안내 컴포넌트가 모달에 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='download-modal']" do
      assert_select "[data-component='subscription-notice']"
    end
  end

  # 구독 안내 텍스트가 포함되는지 확인
  test "구독 안내 텍스트가 표시된다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='subscription-notice']", text: /구독/
  end

  # 구독 페이지 링크가 존재하는지 확인
  test "구독 안내에 설정 페이지 링크가 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='subscription-notice']" do
      assert_select "a[href='/settings']"
    end
  end

  # ----- 모달 오버레이 (배경) -----

  # 모달 배경(오버레이) 요소가 존재하는지 확인
  test "모달 배경 오버레이가 존재한다" do
    get report_path(@fact_check.id)
    assert_select "[data-component='modal-overlay']"
  end

  teardown do
    # 테스트 데이터 정리 (연관 순서대로)
    FactCheck.where(id: @fact_check&.id).delete_all
    Channel.where(id: @channel&.id).delete_all
    User.where(id: @user&.id).delete_all
  end
end
