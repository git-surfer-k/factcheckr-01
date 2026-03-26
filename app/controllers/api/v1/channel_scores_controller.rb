# frozen_string_literal: true

# @TASK P3-R2-T1 - 채널 점수 이력 API 컨트롤러
# @SPEC docs/planning/02-trd.md#채널-점수-API
module Api
  module V1
    # 채널의 신뢰도 점수 추이를 조회하는 컨트롤러.
    # 추이 그래프 렌더링을 위해 recorded_at 오름차순으로 반환한다.
    # 모든 엔드포인트는 인증이 필요하다.
    class ChannelScoresController < ApplicationController
      before_action :set_channel

      # GET /api/v1/channels/:channel_id/scores
      # 채널의 점수 이력을 recorded_at 오름차순으로 반환한다.
      # 파라미터: limit (최대 개수), start_date/end_date (기간 필터)
      def index
        scope = @channel.channel_scores.chronological

        # 기간 필터 (선택)
        if params[:start_date].present? && params[:end_date].present?
          start_date = Time.zone.parse(params[:start_date])
          end_date = Time.zone.parse(params[:end_date])
          scope = scope.by_period(start_date, end_date)
        end

        # 개수 제한 (선택) — 최근 N개를 오름차순으로 반환
        if params[:limit].present?
          limit = params[:limit].to_i
          scope = scope.recent.limit(limit).reorder(recorded_at: :asc)
        end

        render json: {
          scores: scope.map { |score| score_response(score) }
        }
      end

      private

      # 채널을 찾는다. 존재하지 않으면 404를 반환.
      def set_channel
        @channel = Channel.find_by(id: params[:channel_id])

        unless @channel
          render json: { detail: "채널을 찾을 수 없습니다." }, status: :not_found
        end
      end

      # 점수 응답 포맷
      def score_response(score)
        {
          id: score.id,
          channel_id: score.channel_id,
          score: score.score&.to_s,
          accuracy_rate: score.accuracy_rate&.to_s,
          source_citation_rate: score.source_citation_rate&.to_s,
          consistency_score: score.consistency_score&.to_s,
          recorded_at: score.recorded_at
        }
      end
    end
  end
end
