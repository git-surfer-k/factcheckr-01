# frozen_string_literal: true

# @TASK P3-S1-T1 - 채널 상세 페이지 컨트롤러
# @SPEC specs/screens/b2c-channel-detail.yaml
# 채널 상세 정보, 신뢰도 점수 추이, 팩트체크 이력을 서버 사이드 렌더링하는 컨트롤러.
# channel_scores, fact_checks를 eager load하여 N+1 쿼리를 방지한다.
class ChannelsController < ActionController::Base
  # CSRF 보호 활성화
  protect_from_forgery with: :exception

  # 레이아웃 명시 지정
  layout "application"

  # 채널 상세 페이지: /channels/:id
  # 채널과 연관 데이터를 eager load하여 뷰에 전달한다.
  def show
    @channel = Channel.find(params[:id])

    # 신뢰도 추이 데이터: 시간순 정렬 (차트용)
    @channel_scores = @channel.channel_scores.chronological

    # 최신 점수 기록에서 세부 지표를 가져온다 (없으면 nil)
    @latest_score = @channel.channel_scores.recent.first

    # 팩트체크 이력: 최신 순으로 최대 10건 조회
    @fact_checks = @channel.fact_checks
      .where(status: :completed)
      .order(created_at: :desc)
      .limit(10)
  rescue ActiveRecord::RecordNotFound
    # 존재하지 않는 채널은 404 응답
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end
end
