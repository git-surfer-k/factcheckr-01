# frozen_string_literal: true

# @TASK P2-R3-T1 - 근거 뉴스 API 컨트롤러
# @SPEC docs/planning/02-trd.md#팩트체크-API
module Api
  module V1
    # 주장(Claim)별 근거 뉴스를 조회하는 컨트롤러.
    # claim의 fact_check가 현재 사용자의 것인지 검증 후 반환한다.
    class NewsSourcesController < ApplicationController
      before_action :set_claim

      # GET /api/v1/claims/:claim_id/news_sources
      # 특정 주장에 연결된 근거 뉴스 목록을 relevance_score 내림차순으로 반환
      def index
        news_sources = @claim.news_sources.by_relevance

        render json: {
          news_sources: news_sources.map { |ns| news_source_response(ns) }
        }
      end

      private

      # claim을 찾고, 현재 사용자의 것인지 권한을 검증한다
      def set_claim
        @claim = Claim.find_by(id: params[:claim_id])

        unless @claim
          render json: { detail: "주장을 찾을 수 없습니다." }, status: :not_found
          return
        end

        # claim -> fact_check -> user 관계를 통해 접근 권한 검증
        unless @claim.fact_check.user_id == current_user.id
          render json: { detail: "이 주장에 대한 접근 권한이 없습니다." }, status: :forbidden
          return
        end
      end

      # 근거 뉴스 응답 포맷
      def news_source_response(news_source)
        {
          id: news_source.id,
          claim_id: news_source.claim_id,
          title: news_source.title,
          url: news_source.url,
          publisher: news_source.publisher,
          author: news_source.author,
          published_at: news_source.published_at,
          relevance_score: news_source.relevance_score,
          bigkinds_doc_id: news_source.bigkinds_doc_id
        }
      end
    end
  end
end
