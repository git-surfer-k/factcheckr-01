# frozen_string_literal: true

# @TASK P2-R2-T1 - 팩트체크별 주장 목록 API 컨트롤러
# @SPEC docs/planning/02-trd.md#팩트체크-API
module Api
  module V1
    # 팩트체크(FactCheck)에 속한 주장(Claim) 목록을 조회하는 컨트롤러.
    # fact_check가 현재 사용자의 것인지 검증 후 반환한다.
    class ClaimsController < ApplicationController
      before_action :set_fact_check

      # GET /api/v1/fact_checks/:fact_check_id/claims
      # 특정 팩트체크에 속한 주장 목록을 timestamp_start 오름차순으로 반환
      def index
        claims = @fact_check.claims.ordered

        render json: {
          claims: claims.map { |claim| claim_response(claim) }
        }
      end

      private

      # fact_check를 찾고, 현재 사용자의 것인지 권한을 검증한다
      def set_fact_check
        @fact_check = current_user.fact_checks.find_by(id: params[:fact_check_id])

        unless @fact_check
          render json: { detail: "팩트체크를 찾을 수 없습니다." }, status: :not_found
        end
      end

      # 주장 응답 포맷 (embedding은 내부용이므로 제외)
      def claim_response(claim)
        {
          id: claim.id,
          fact_check_id: claim.fact_check_id,
          claim_text: claim.claim_text,
          verdict: claim.verdict,
          confidence: claim.confidence,
          explanation: claim.explanation,
          timestamp_start: claim.timestamp_start,
          timestamp_end: claim.timestamp_end,
          created_at: claim.created_at,
          updated_at: claim.updated_at
        }
      end
    end
  end
end
