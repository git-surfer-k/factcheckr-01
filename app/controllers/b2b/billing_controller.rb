# frozen_string_literal: true

# @TASK P5-S5-T1 - B2B 결제 관리 컨트롤러
# @SPEC specs/screens/b2b-billing.yaml
# B2B 기업 사용자의 구독/결제 정보를 보여준다.
# 로그인 필수 + B2B 사용자만 접근 가능.
module B2b
  class BillingController < ActionController::Base
    # CSRF 보호 활성화
    protect_from_forgery with: :exception

    # B2B 전용 레이아웃 사용
    layout "b2b"

    # 모든 액션 전에 B2B 인증 확인
    before_action :authenticate_b2b_user!

    # GET /b2b/billing
    # 현재 사용자의 구독 정보와 결제 이력을 조회하여 렌더링한다.
    def index
      # 현재 활성 구독 조회 (없으면 nil)
      @current_subscription = current_b2b_user.subscriptions
                                              .active
                                              .order(created_at: :desc)
                                              .first

      # MVP: 결제 이력은 빈 배열 (추후 결제 API 연동 시 구현)
      @billing_history = []
    end

    private

    # B2B 세션 쿠키로 현재 사용자를 인증한다.
    # 미인증이면 로그인 페이지로 리다이렉트.
    def authenticate_b2b_user!
      token = cookies[:b2b_session_token]

      unless token.present?
        redirect_to b2b_login_path, alert: "로그인이 필요합니다."
        return
      end

      db_session = Session.find_by(token: token)

      unless db_session
        redirect_to b2b_login_path, alert: "세션이 만료되었습니다. 다시 로그인해 주세요."
        return
      end

      user = db_session.user

      # 비활성 계정 차단
      unless user&.is_active
        redirect_to b2b_login_path, alert: "비활성화된 계정입니다."
        return
      end

      # B2B 사용자만 허용 (B2C 사용자 차단)
      unless user.b2b?
        redirect_to b2b_login_path, alert: "B2B 계정으로만 접근할 수 있습니다."
        return
      end

      @current_b2b_user = user
    end

    # 현재 로그인된 B2B 사용자를 반환한다.
    def current_b2b_user
      @current_b2b_user
    end

    # 뷰에서도 current_b2b_user를 사용할 수 있도록 헬퍼로 공개
    helper_method :current_b2b_user
  end
end
