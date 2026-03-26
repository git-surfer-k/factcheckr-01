# frozen_string_literal: true

# @TASK P1-R1-T1 - 사용자 프로필 관리 API
# @SPEC specs/domain/resources.yaml#users
module Api
  module V1
    # 사용자 프로필 조회, 수정, 비활성화(탈퇴) 컨트롤러.
    # 인증된 사용자만 자신의 정보에 접근할 수 있다.
    class UsersController < ApplicationController
      include UserSerializable

      # GET /api/v1/users/me
      # 현재 인증된 사용자 정보를 반환
      def me
        render json: user_response(current_user)
      end

      # PATCH /api/v1/users/me
      # 사용자 이름(name) 업데이트. email, user_type 등은 변경 불가.
      def update_me
        if current_user.update(update_params)
          render json: user_response(current_user)
        else
          render json: { detail: current_user.errors.full_messages.join(", ") }, status: :bad_request
        end
      end

      # DELETE /api/v1/users/me
      # 계정 비활성화 (소프트 삭제 — is_active를 false로 설정)
      def destroy_me
        current_user.update!(is_active: false)
        head :no_content
      end

      private

      # 허용된 파라미터: name만 수정 가능
      def update_params
        params.permit(:name)
      end
    end
  end
end
