# frozen_string_literal: true

module Api
  module V1
    class BookmarksController < ApplicationController
      def create
        fact_check = FactCheck.find_by(id: params[:fact_check_id])
        return render json: { detail: "팩트체크를 찾을 수 없습니다." }, status: :not_found unless fact_check

        bookmark = current_user.bookmarks.find_or_initialize_by(fact_check_id: fact_check.id)
        if bookmark.new_record? && bookmark.save
          render json: { message: "내 기록에 저장되었습니다.", bookmarked: true }, status: :created
        else
          render json: { message: "이미 저장된 리포트입니다.", bookmarked: true }, status: :ok
        end
      end

      def destroy
        bookmark = current_user.bookmarks.find_by(fact_check_id: params[:id])
        if bookmark&.destroy
          render json: { message: "내 기록에서 삭제되었습니다.", bookmarked: false }
        else
          render json: { detail: "저장된 기록을 찾을 수 없습니다." }, status: :not_found
        end
      end
    end
  end
end
