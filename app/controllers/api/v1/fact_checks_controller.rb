# frozen_string_literal: true

# @TASK P2-R1-T1 - 팩트체크 API 컨트롤러
# @SPEC docs/planning/02-trd.md#팩트체크-API
module Api
  module V1
    # 팩트체크 요청 생성, 상태/결과 조회, 목록 조회 컨트롤러.
    # 모든 엔드포인트는 인증이 필요하며, 현재 사용자의 데이터만 접근 가능하다.
    class FactChecksController < ApplicationController
      # 페이지네이션 기본값
      DEFAULT_PER_PAGE = 10
      MAX_PER_PAGE = 50

      # POST /api/v1/fact_checks
      # 유튜브 URL로 새 팩트체크 요청을 생성한다.
      # 채널이 존재하지 않으면 임시 채널 레코드를 자동 생성한다.
      def create
        youtube_url = params[:youtube_url]&.strip

        if youtube_url.blank?
          render json: { detail: "youtube_url을 입력해 주세요." }, status: :bad_request
          return
        end

        # 임시 채널 생성 또는 기존 채널 조회
        # (실제 채널 정보는 AI 파이프라인에서 yt-dlp로 업데이트)
        channel = find_or_create_channel(youtube_url)

        fact_check = current_user.fact_checks.build(
          channel: channel,
          youtube_url: youtube_url,
          status: :pending
        )

        if fact_check.save
          render json: fact_check_response(fact_check), status: :created
        else
          render json: { detail: fact_check.errors.full_messages.join(", ") },
            status: :unprocessable_entity
        end
      end

      # GET /api/v1/fact_checks/:id
      # 특정 팩트체크의 상태 및 분석 결과를 조회한다.
      # 현재 사용자의 팩트체크만 조회 가능 (다른 사용자 것은 404).
      def show
        fact_check = current_user.fact_checks.find_by(id: params[:id])

        unless fact_check
          render json: { detail: "팩트체크를 찾을 수 없습니다." }, status: :not_found
          return
        end

        render json: fact_check_detail_response(fact_check)
      end

      # GET /api/v1/fact_checks
      # 현재 사용자의 팩트체크 목록을 페이지네이션하여 반환한다.
      # 파라미터: page (기본 1), per_page (기본 10, 최대 50), status (필터)
      def index
        scope = current_user.fact_checks.recent

        # status 필터 (선택)
        if params[:status].present? && FactCheck.statuses.key?(params[:status])
          scope = scope.by_status(params[:status])
        end

        # 페이지네이션 계산
        page = [ params.fetch(:page, 1).to_i, 1 ].max
        per_page = [ params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE), 1 ].max
        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        offset = (page - 1) * per_page

        fact_checks = scope.limit(per_page).offset(offset)

        render json: {
          fact_checks: fact_checks.map { |fc| fact_check_response(fc) },
          meta: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages
          }
        }
      end

      private

      # 팩트체크 목록용 응답 포맷 (요약 정보)
      def fact_check_response(fact_check)
        {
          id: fact_check.id,
          user_id: fact_check.user_id,
          channel_id: fact_check.channel_id,
          youtube_video_id: fact_check.youtube_video_id,
          youtube_url: fact_check.youtube_url,
          video_title: fact_check.video_title,
          video_thumbnail: fact_check.video_thumbnail,
          status: fact_check.status,
          overall_score: fact_check.overall_score&.to_s,
          created_at: fact_check.created_at,
          completed_at: fact_check.completed_at
        }
      end

      # 팩트체크 상세 응답 포맷 (전체 분석 결과 포함)
      def fact_check_detail_response(fact_check)
        {
          id: fact_check.id,
          user_id: fact_check.user_id,
          channel_id: fact_check.channel_id,
          youtube_video_id: fact_check.youtube_video_id,
          youtube_url: fact_check.youtube_url,
          video_title: fact_check.video_title,
          video_thumbnail: fact_check.video_thumbnail,
          transcript: fact_check.transcript,
          summary: fact_check.summary,
          overall_score: fact_check.overall_score&.to_s,
          analysis_detail: fact_check.analysis_detail,
          status: fact_check.status,
          created_at: fact_check.created_at,
          completed_at: fact_check.completed_at
        }
      end

      # 유튜브 URL에서 임시 채널을 찾거나 생성한다.
      # 실제 채널 정보는 이후 AI 파이프라인에서 yt-dlp를 통해 업데이트된다.
      def find_or_create_channel(youtube_url)
        # 임시 채널 ID 생성 (실제 채널 ID는 AI 서버에서 업데이트)
        temp_channel_id = "pending_#{SecureRandom.hex(8)}"

        Channel.create!(
          youtube_channel_id: temp_channel_id,
          name: "분석 대기 중"
        )
      end
    end
  end
end
