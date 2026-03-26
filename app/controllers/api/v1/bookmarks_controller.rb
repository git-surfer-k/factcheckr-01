# frozen_string_literal: true

# 내 기록 담기/삭제 API
module Api
  module V1
    class BookmarksController < ApplicationController
      # POST /api/v1/bookmarks — 리포트를 내 기록에 담기
      def create
        fact_check = FactCheck.find_by(id: params[:fact_check_id])
        unless fact_check
          render json: { error: "팩트체크를 찾을 수 없습니다." }, status: :not_found and return
        end

        bookmark = current_user.bookmarks.find_or_initialize_by(fact_check: fact_check)
        if bookmark.new_record? && bookmark.save
          render json: { message: "내 기록에 저장되었습니다.", bookmarked: true }, status: :created
        elsif bookmark.persisted?
          render json: { message: "이미 저장된 리포트입니다.", bookmarked: true }, status: :ok
        else
          render json: { error: bookmark.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/bookmarks/:id — 내 기록에서 삭제
      def destroy
        bookmark = current_user.bookmarks.find_by(fact_check_id: params[:id])
        if bookmark&.destroy
          render json: { message: "내 기록에서 삭제되었습니다.", bookmarked: false }
        else
          render json: { error: "저장된 기록을 찾을 수 없습니다." }, status: :not_found
        end
      end
    end
  end
end
