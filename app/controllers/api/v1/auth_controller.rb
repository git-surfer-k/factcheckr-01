# frozen_string_literal: true

# @TASK P0-T0.4 - Email OTP 인증 컨트롤러
# @TASK P1-R1-T1 - user_type 필드 추가
# @SPEC docs/planning/02-trd.md#인증-API
module Api
  module V1
    # Email OTP 기반 인증 컨트롤러.
    # 이메일로 6자리 OTP를 발송하고, 검증 후 세션을 생성한다.
    # 신규 사용자는 OTP 검증 시 자동 가입된다.
    class AuthController < ApplicationController
      include UserSerializable

      skip_before_action :authenticate_user!, only: %i[request_otp verify_otp]

      # POST /api/v1/auth/request_otp
      # 이메일 주소로 6자리 OTP 발송
      def request_otp
        email = params[:email]&.strip&.downcase

        if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
          render json: { detail: "올바른 이메일 주소를 입력해 주세요." }, status: :bad_request
          return
        end

        # 기존 사용자 찾기 또는 나중에 verify_otp에서 생성
        user = User.find_or_initialize_by(email: email)

        if user.new_record?
          # 신규 사용자: 아직 저장하지 않고 OTP만 생성
          user.user_type = :b2c
          user.save!
        end

        # 비활성 사용자 차단
        unless user.is_active
          render json: { detail: "비활성화된 계정입니다." }, status: :forbidden
          return
        end

        # OTP 생성 및 이메일 발송
        user.generate_otp!

        # 이메일 발송 시도 (실패해도 OTP 응답은 정상 반환)
        email_sent = false
        begin
          OtpMailer.send_otp(user).deliver_now
          email_sent = true
        rescue StandardError => e
          Rails.logger.warn "[OTP] 이메일 발송 실패 (#{e.message}), OTP를 응답에 포함합니다."
        end

        response_body = {
          message: email_sent ? "인증 코드가 이메일로 발송되었습니다." : "인증 코드가 생성되었습니다.",
          email: user.email
        }
        # 이메일 발송 실패 시 OTP를 응답에 포함 (도메인 등록 전 임시 조치)
        response_body[:otp_code] = user.otp_code unless email_sent

        render json: response_body
      end

      # POST /api/v1/auth/verify_otp
      # OTP 검증 후 세션 생성 (신규 사용자면 자동 가입 완료)
      def verify_otp
        email = params[:email]&.strip&.downcase
        otp_code = params[:otp_code]

        if email.blank? || otp_code.blank?
          render json: { detail: "이메일과 인증 코드를 모두 입력해 주세요." }, status: :bad_request
          return
        end

        user = User.find_by(email: email)

        unless user
          render json: { detail: "인증 코드가 올바르지 않거나 만료되었습니다." }, status: :unauthorized
          return
        end

        unless user.is_active
          render json: { detail: "비활성화된 계정입니다." }, status: :forbidden
          return
        end

        # OTP 검증 (일치 + 만료 확인)
        unless user.verify_otp(otp_code)
          render json: { detail: "인증 코드가 올바르지 않거나 만료되었습니다." }, status: :unauthorized
          return
        end

        # 세션 생성
        session = user.create_session!

        render json: {
          message: "로그인 성공",
          session_token: session.token,
          user: user_response(user)
        }
      end

      # DELETE /api/v1/auth/logout
      # 현재 세션 삭제
      def logout
        if current_session
          current_session.destroy
        end

        render json: { message: "로그아웃 되었습니다." }
      end

    end
  end
end
