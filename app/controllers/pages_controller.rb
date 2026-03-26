# frozen_string_literal: true

# @TASK P1-S0-T1 - 기본 페이지 컨트롤러
# 홈, 랭킹, 내기록, 설정 페이지를 렌더링하는 컨트롤러.
# API 컨트롤러(ActionController::API)와 다르게 뷰와 레이아웃을 지원한다.
class PagesController < ActionController::Base
  # CSRF 보호 활성화 (API가 아닌 웹 페이지이므로 필요)
  protect_from_forgery with: :exception

  # 레이아웃 명시 지정 (application.html.erb 사용)
  layout "application"

  # 홈 페이지
  def home
  end

  # 채널 랭킹 페이지
  def ranking
  end

  # 내 팩트체크 기록 페이지
  def history
  end

  # 설정 페이지
  def settings
  end
end
