# frozen_string_literal: true

# @TASK P2-S3-T1 - 리포트 상세 페이지 컨트롤러
# @SPEC specs/screens/b2c-report-detail.yaml
# 팩트체크 결과 상세 리포트를 서버 사이드 렌더링하는 컨트롤러.
# fact_check, claims, news_sources, channel을 eager load하여 N+1 쿼리를 방지한다.
class ReportsController < ActionController::Base
  # CSRF 보호 활성화
  protect_from_forgery with: :exception

  # 레이아웃 명시 지정
  layout "application"

  # 리포트 상세 페이지: /reports/:id
  # fact_check와 연관 데이터를 eager load하여 뷰에 전달한다.
  def show
    # claims → news_sources 순으로 eager load하여 N+1 방지
    @fact_check = FactCheck.includes(claims: :news_sources, channel: {}).find(params[:id])
    @claims = @fact_check.claims.ordered
    @channel = @fact_check.channel

    # 모든 news_sources를 하나의 배열로 모은다 (근거 뉴스 탭용)
    @all_news_sources = @claims.flat_map(&:news_sources)
      .sort_by { |ns| -(ns.relevance_score || 0) }

    # 북마크 여부 확인
    @bookmarked = current_web_user&.bookmarks&.exists?(fact_check: @fact_check) || false
  rescue ActiveRecord::RecordNotFound
    # 존재하지 않는 리포트는 404 응답
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end

  private

  def current_web_user
    return @current_web_user if defined?(@current_web_user)
    token = session[:session_token] || cookies[:session_token]
    return @current_web_user = nil unless token
    web_session = Session.find_by_token(token)
    @current_web_user = web_session&.user&.then { |u| u.is_active ? u : nil }
  end

  helper_method :current_web_user
end
