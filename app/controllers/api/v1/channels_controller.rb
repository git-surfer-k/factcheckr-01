# frozen_string_literal: true

# @TASK P3-R1-T1 - 채널 목록/랭킹 및 상세 조회 API 컨트롤러
# @SPEC docs/planning/02-trd.md#채널-API
module Api
  module V1
    # 채널 목록(랭킹)과 상세 정보를 조회하는 컨트롤러.
    # 카테고리 필터, 이름 검색, trust_score 내림차순 정렬, 페이지네이션을 지원한다.
    # 모든 엔드포인트는 인증이 필요하다.
    class ChannelsController < ApplicationController
      # 페이지네이션 기본값
      DEFAULT_PER_PAGE = 10
      MAX_PER_PAGE = 50

      # GET /api/v1/channels
      # 채널 목록을 trust_score 내림차순(랭킹)으로 반환한다.
      # 파라미터: category (필터), search (이름 검색), page (기본 1), per_page (기본 10, 최대 50)
      def index
        scope = Channel.ranked_by_trust

        # 카테고리 필터 (선택)
        if params[:category].present?
          scope = scope.by_category(params[:category])
        end

        # 이름 검색 (선택)
        if params[:search].present?
          scope = scope.search_by_name(params[:search])
        end

        # 페이지네이션 계산
        page = [params.fetch(:page, 1).to_i, 1].max
        per_page = [params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE), 1].max
        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        offset = (page - 1) * per_page

        channels = scope.limit(per_page).offset(offset)

        render json: {
          channels: channels.map { |ch| channel_response(ch) },
          meta: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages
          }
        }
      end

      # GET /api/v1/channels/:id
      # 특정 채널의 상세 정보를 조회한다.
      def show
        channel = Channel.find_by(id: params[:id])

        unless channel
          render json: { detail: "채널을 찾을 수 없습니다." }, status: :not_found
          return
        end

        render json: channel_response(channel)
      end

      private

      # 채널 응답 포맷
      def channel_response(channel)
        {
          id: channel.id,
          youtube_channel_id: channel.youtube_channel_id,
          name: channel.name,
          description: channel.description,
          subscriber_count: channel.subscriber_count,
          category: channel.category,
          trust_score: channel.trust_score&.to_s,
          total_checks: channel.total_checks,
          thumbnail_url: channel.thumbnail_url,
          created_at: channel.created_at
        }
      end
    end
  end
end
