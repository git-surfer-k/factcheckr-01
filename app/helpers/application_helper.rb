# frozen_string_literal: true

# @TASK P2-S1-T1 - 공통 뷰 헬퍼
# ScoreBadge 등 뷰에서 재사용되는 헬퍼 메서드를 정의한다.
module ApplicationHelper
  # 팩트체크 썸네일 URL을 반환한다.
  # video_thumbnail이 있으면 그대로, 없으면 동적 SVG 썸네일 사용
  def fact_check_thumbnail_url(check)
    if check.video_thumbnail.present?
      check.video_thumbnail
    else
      thumbnail_path(check.id, v: 2)
    end
  end

  # 팩트체크 점수에 따라 원형 배지 테두리 색상 클래스를 반환한다.
  def score_border_class(score)
    case score.to_f
    when 90..100 then "border-green-400"
    when 70..89  then "border-emerald-400"
    when 50..69  then "border-yellow-400"
    when 30..49  then "border-orange-400"
    else              "border-red-400"
    end
  end

  # 팩트체크 점수에 따라 숫자 텍스트 색상 클래스를 반환한다.
  def score_number_class(score)
    case score.to_f
    when 90..100 then "text-green-600"
    when 70..89  then "text-emerald-600"
    when 50..69  then "text-yellow-600"
    when 30..49  then "text-orange-600"
    else              "text-red-600"
    end
  end

  # 팩트체크 점수에 따라 점수 바 색상 클래스를 반환한다.
  def score_bar_class(score)
    case score.to_f
    when 90..100 then "bg-green-500"
    when 70..89  then "bg-emerald-500"
    when 50..69  then "bg-yellow-500"
    when 30..49  then "bg-orange-500"
    else              "bg-red-500"
    end
  end

  # 팩트체크 점수에 따라 색상 CSS 클래스를 반환한다.
  # 90 이상: 초록(green), 70-89: 에메랄드(emerald), 50-69: 노랑(yellow),
  # 30-49: 주황(orange), 0-29: 빨강(red)
  def score_color_classes(score)
    case score
    when 90..100 then "bg-green-100 text-green-700"
    when 70..89  then "bg-emerald-100 text-emerald-700"
    when 50..69  then "bg-yellow-100 text-yellow-700"
    when 30..49  then "bg-orange-100 text-orange-700"
    else              "bg-red-100 text-red-700"
    end
  end

  # 팩트체크 점수에 따른 판정 라벨을 반환한다.
  def score_label(score)
    case score
    when 90..100 then "매우 신뢰"
    when 70..89  then "신뢰"
    when 50..69  then "보통"
    when 30..49  then "주의"
    else              "위험"
    end
  end

  # verdict(판정) 값에 따라 색상 CSS 클래스를 반환한다.
  # true_claim: 초록, mostly_true: 에메랄드, half_true: 노랑,
  # mostly_false: 주황, false_claim: 빨강, unverified: 회색
  def verdict_color_classes(verdict)
    case verdict.to_s
    when "true_claim"    then { bg: "bg-green-100",   text: "text-green-700",   border: "border-green-200",   bar: "bg-green-500" }
    when "mostly_true"   then { bg: "bg-emerald-100", text: "text-emerald-700", border: "border-emerald-200", bar: "bg-emerald-500" }
    when "half_true"     then { bg: "bg-yellow-100",  text: "text-yellow-700",  border: "border-yellow-200",  bar: "bg-yellow-500" }
    when "mostly_false"  then { bg: "bg-orange-100",  text: "text-orange-700",  border: "border-orange-200",  bar: "bg-orange-500" }
    when "false_claim"   then { bg: "bg-red-100",     text: "text-red-700",     border: "border-red-200",     bar: "bg-red-500" }
    else                      { bg: "bg-gray-100",    text: "text-gray-500",    border: "border-gray-200",    bar: "bg-gray-400" }
    end
  end

  # verdict 값에 따라 한국어 라벨을 반환한다.
  def verdict_label(verdict)
    case verdict.to_s
    when "true_claim"   then "사실"
    when "mostly_true"  then "대체로 사실"
    when "half_true"    then "절반 사실"
    when "mostly_false" then "대체로 거짓"
    when "false_claim"  then "거짓"
    else "미검증"
    end
  end

  # verdict 값에 따라 SVG 아이콘 경로(path d 속성)와 색상을 반환한다.
  def verdict_icon_svg(verdict)
    case verdict.to_s
    when "true_claim", "mostly_true"
      # 체크 아이콘
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />'
    when "half_true"
      # 물음표(느낌표) 아이콘
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01M12 4a8 8 0 100 16 8 8 0 000-16z" />'
    when "mostly_false", "false_claim"
      # X 아이콘
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />'
    else
      # 대시 아이콘
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />'
    end
  end

  # 타임스탬프(초)를 MM:SS 형식으로 변환한다.
  def format_timestamp(seconds)
    return nil if seconds.nil?

    minutes = seconds / 60
    secs = seconds % 60
    format("%02d:%02d", minutes, secs)
  end

  # 생성 시각을 "N시간 전", "N일 전" 등 상대 시각 문자열로 변환한다.
  def relative_time(time)
    diff = Time.current - time
    if diff < 1.hour
      "#{(diff / 60).to_i}분 전"
    elsif diff < 1.day
      "#{(diff / 1.hour).to_i}시간 전"
    elsif diff < 1.week
      "#{(diff / 1.day).to_i}일 전"
    else
      time.strftime("%Y. %m. %d.")
    end
  end
end
