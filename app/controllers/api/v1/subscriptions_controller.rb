# frozen_string_literal: true

# @TASK P1-R2-T1 - 구독 관리 컨트롤러
# @SPEC docs/planning/02-trd.md#구독-API
module Api
  module V1
    # 사용자 구독 플랜을 관리하는 컨트롤러.
    # 현재 구독 조회, 생성, 변경, 취소 기능을 제공한다.
    class SubscriptionsController < ApplicationController
      VALID_PLAN_TYPES = Subscription.plan_types.keys.freeze

      # GET /api/v1/subscriptions/current
      # 현재 사용자의 활성 구독을 조회
      def current
        subscription = current_user.subscriptions.active.order(created_at: :desc).first

        unless subscription
          render json: { detail: "활성 구독이 없습니다." }, status: :not_found
          return
        end

        render json: subscription_response(subscription)
      end

      # POST /api/v1/subscriptions
      # 새 구독을 생성 (이미 활성 구독이 있으면 409 충돌)
      def create
        # plan_type 파라미터 검증
        plan_type = params[:plan_type]
        unless plan_type.present? && VALID_PLAN_TYPES.include?(plan_type)
          render json: { detail: "올바른 plan_type을 입력해 주세요. (#{VALID_PLAN_TYPES.join(', ')})" }, status: :bad_request
          return
        end

        # 이미 활성 구독이 있는지 확인
        if current_user.subscriptions.active.exists?
          render json: { detail: "이미 활성 구독이 있습니다. 기존 구독을 취소한 후 새로 생성해 주세요." }, status: :conflict
          return
        end

        subscription = current_user.subscriptions.build(
          plan_type: plan_type,
          status: :active,
          started_at: Time.current,
          expires_at: 30.days.from_now,
          payment_method: params[:payment_method]
        )

        if subscription.save
          render json: subscription_response(subscription), status: :created
        else
          render json: { detail: subscription.errors.full_messages.join(", ") }, status: :bad_request
        end
      end

      # PUT /api/v1/subscriptions/:id
      # 구독 플랜 또는 결제 수단 변경
      def update
        subscription = current_user.subscriptions.find_by(id: params[:id])

        unless subscription
          render json: { detail: "구독을 찾을 수 없습니다." }, status: :not_found
          return
        end

        unless subscription.active?
          render json: { detail: "활성 구독만 변경할 수 있습니다." }, status: :unprocessable_entity
          return
        end

        # plan_type 검증 (입력된 경우에만)
        if params[:plan_type].present? && !VALID_PLAN_TYPES.include?(params[:plan_type])
          render json: { detail: "올바른 plan_type을 입력해 주세요. (#{VALID_PLAN_TYPES.join(', ')})" }, status: :bad_request
          return
        end

        update_attrs = {}
        update_attrs[:plan_type] = params[:plan_type] if params[:plan_type].present?
        update_attrs[:payment_method] = params[:payment_method] if params.key?(:payment_method)

        if subscription.update(update_attrs)
          render json: subscription_response(subscription)
        else
          render json: { detail: subscription.errors.full_messages.join(", ") }, status: :bad_request
        end
      end

      # DELETE /api/v1/subscriptions/:id
      # 구독 취소 (status를 canceled로 변경, 실제 삭제하지 않음)
      def destroy
        subscription = current_user.subscriptions.find_by(id: params[:id])

        unless subscription
          render json: { detail: "구독을 찾을 수 없습니다." }, status: :not_found
          return
        end

        if subscription.canceled?
          render json: { detail: "이미 취소된 구독입니다." }, status: :unprocessable_entity
          return
        end

        subscription.update!(status: :canceled)

        render json: {
          message: "구독이 취소되었습니다.",
          **subscription_response(subscription)
        }
      end

      private

      # 구독 응답 포맷
      def subscription_response(subscription)
        {
          id: subscription.id,
          user_id: subscription.user_id,
          plan_type: subscription.plan_type,
          status: subscription.status,
          started_at: subscription.started_at,
          expires_at: subscription.expires_at,
          payment_method: subscription.payment_method,
          created_at: subscription.created_at,
          updated_at: subscription.updated_at
        }
      end
    end
  end
end
