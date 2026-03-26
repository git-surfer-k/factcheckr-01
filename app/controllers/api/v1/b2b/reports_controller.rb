# frozen_string_literal: true

# @TASK P5-R1-T1 - B2B 광고적합성 리포트 API 컨트롤러
# @SPEC docs/planning/02-trd.md#B2B-리포트-API
module Api
  module V1
    module B2b
      # B2B 기업용 광고적합성 리포트 요청/조회 컨트롤러.
      # B2B 사용자(user_type == 'b2b')만 접근 가능하며,
      # 현재 사용자의 리포트만 조회할 수 있다.
      class ReportsController < ApplicationController
        # B2B 사용자 권한 검증 (인증 후 실행)
        before_action :require_b2b_user!

        # 페이지네이션 기본값
        DEFAULT_PER_PAGE = 10
        MAX_PER_PAGE = 50

        # POST /api/v1/b2b/reports
        # 새 B2B 리포트 요청을 생성한다.
        # 필수: company_name, industry / 선택: product_info, target_categories
        def create
          report = current_user.b2b_reports.build(
            company_name: params[:company_name],
            industry: params[:industry],
            product_info: params[:product_info],
            target_categories: params[:target_categories],
            status: :pending
          )

          if report.save
            render json: report_response(report), status: :created
          else
            render json: { detail: report.errors.full_messages.join(", ") },
              status: :unprocessable_entity
          end
        end

        # GET /api/v1/b2b/reports/:id
        # 특정 리포트의 상세 정보를 조회한다.
        # 현재 사용자의 리포트만 조회 가능 (다른 사용자 것은 404).
        def show
          report = current_user.b2b_reports.find_by(id: params[:id])

          unless report
            render json: { detail: "리포트를 찾을 수 없습니다." }, status: :not_found
            return
          end

          render json: report_detail_response(report)
        end

        # GET /api/v1/b2b/reports
        # 현재 사용자의 리포트 목록을 페이지네이션하여 반환한다.
        # 파라미터: page (기본 1), per_page (기본 10, 최대 50), status (필터)
        def index
          scope = current_user.b2b_reports.recent

          # status 필터 (선택)
          if params[:status].present? && B2bReport.statuses.key?(params[:status])
            scope = scope.by_status(params[:status])
          end

          # 페이지네이션 계산
          page = [ params.fetch(:page, 1).to_i, 1 ].max
          per_page = [ params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE), 1 ].max
          total_count = scope.count
          total_pages = (total_count.to_f / per_page).ceil
          offset = (page - 1) * per_page

          reports = scope.limit(per_page).offset(offset)

          render json: {
            reports: reports.map { |r| report_response(r) },
            meta: {
              current_page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: total_pages
            }
          }
        end

        private

        # B2B 사용자 권한 검증: user_type이 'b2b'가 아니면 403 반환
        def require_b2b_user!
          return if current_user&.b2b?

          render json: { detail: "B2B 사용자만 접근할 수 있습니다." }, status: :forbidden
        end

        # 리포트 목록용 응답 포맷 (요약 정보)
        def report_response(report)
          {
            id: report.id,
            user_id: report.user_id,
            company_name: report.company_name,
            industry: report.industry,
            product_info: report.product_info,
            target_categories: report.target_categories,
            status: report.status,
            completed_at: report.completed_at,
            created_at: report.created_at,
            updated_at: report.updated_at
          }
        end

        # 리포트 상세 응답 포맷 (전체 데이터 포함)
        def report_detail_response(report)
          {
            id: report.id,
            user_id: report.user_id,
            company_name: report.company_name,
            industry: report.industry,
            product_info: report.product_info,
            target_categories: report.target_categories,
            recommended_channels: report.recommended_channels,
            report_data: report.report_data,
            status: report.status,
            completed_at: report.completed_at,
            created_at: report.created_at,
            updated_at: report.updated_at
          }
        end
      end
    end
  end
end
