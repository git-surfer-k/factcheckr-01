# frozen_string_literal: true

# @TASK P2-S1-T1 - ApplicationHelper 단위 테스트
# ScoreBadge 헬퍼의 색상 클래스와 라벨이 올바르게 반환되는지 검증
require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  # ===== score_color_classes 테스트 =====

  test "90점 이상은 초록(green) 클래스를 반환한다" do
    assert_includes score_color_classes(90), "green"
    assert_includes score_color_classes(100), "green"
    assert_includes score_color_classes(95), "green"
  end

  test "70~89점은 에메랄드(emerald) 클래스를 반환한다" do
    assert_includes score_color_classes(70), "emerald"
    assert_includes score_color_classes(89), "emerald"
    assert_includes score_color_classes(80), "emerald"
  end

  test "50~69점은 노랑(yellow) 클래스를 반환한다" do
    assert_includes score_color_classes(50), "yellow"
    assert_includes score_color_classes(69), "yellow"
    assert_includes score_color_classes(60), "yellow"
  end

  test "30~49점은 주황(orange) 클래스를 반환한다" do
    assert_includes score_color_classes(30), "orange"
    assert_includes score_color_classes(49), "orange"
    assert_includes score_color_classes(40), "orange"
  end

  test "29점 이하는 빨강(red) 클래스를 반환한다" do
    assert_includes score_color_classes(0), "red"
    assert_includes score_color_classes(29), "red"
    assert_includes score_color_classes(10), "red"
  end

  # ===== score_label 테스트 =====

  test "90점 이상은 '매우 신뢰' 라벨을 반환한다" do
    assert_equal "매우 신뢰", score_label(90)
    assert_equal "매우 신뢰", score_label(100)
  end

  test "70~89점은 '신뢰' 라벨을 반환한다" do
    assert_equal "신뢰", score_label(70)
    assert_equal "신뢰", score_label(89)
  end

  test "50~69점은 '보통' 라벨을 반환한다" do
    assert_equal "보통", score_label(50)
    assert_equal "보통", score_label(69)
  end

  test "30~49점은 '주의' 라벨을 반환한다" do
    assert_equal "주의", score_label(30)
    assert_equal "주의", score_label(49)
  end

  test "29점 이하는 '위험' 라벨을 반환한다" do
    assert_equal "위험", score_label(0)
    assert_equal "위험", score_label(29)
  end

  # ===== relative_time 테스트 =====

  test "30분 전은 '30분 전'을 반환한다" do
    result = relative_time(30.minutes.ago)
    assert_includes result, "분 전"
  end

  test "2시간 전은 '2시간 전'을 반환한다" do
    result = relative_time(2.hours.ago)
    assert_includes result, "시간 전"
  end

  test "3일 전은 '3일 전'을 반환한다" do
    result = relative_time(3.days.ago)
    assert_includes result, "일 전"
  end

  test "10일 전은 날짜 형식으로 반환한다" do
    result = relative_time(10.days.ago)
    assert_match(/\d{4}\. \d{2}\. \d{2}\./, result)
  end
end
