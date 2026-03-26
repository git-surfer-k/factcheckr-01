# frozen_string_literal: true

# @TASK P5-S1-T1 - B2B 로그인 세션 컨트롤러
# @SPEC docs/planning/02-trd.md#인증-API
# B2B 기업 사용자의 로그인을 처리한다.
# Email OTP 방식을 사용하며, 기존 API 엔드포인트를 활용한다.
module B2b
  class SessionsController < ActionController::Base
    # CSRF 보호 활성화 (ActionController::Base 상속으로 자동 적용)
    protect_from_forgery with: :exception

    # B2B 전용 레이아웃 사용
    layout "b2b"

    # GET /b2b/login
    # B2B 로그인 폼을 렌더링한다.
    def new
      # 이미 로그인된 B2B 사용자는 대시보드로 리다이렉트 (추후 구현)
    end

    # POST /b2b/login
    # OTP 요청 또는 OTP 검증을 처리한다.
    # params[:step]이 'verify'면 OTP 검증, 아니면 OTP 요청 단계
    def create
      step = params[:step].to_s

      if step == "verify"
        handle_verify_otp
      else
        handle_request_otp
      end
    end

    private

    # 1단계: 이메일로 OTP 발송 요청
    def handle_request_otp
      email = params[:email]&.strip&.downcase

      if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
        flash.now[:alert] = "올바른 이메일 주소를 입력해 주세요."
        render :new, status: :unprocessable_entity
        return
      end

      # B2B 사용자 찾기 또는 신규 생성
      user = User.find_or_initialize_by(email: email)
      if user.new_record?
        # B2B 사용자로 신규 생성
        user.user_type = :b2b
        user.save!
      end

      unless user.is_active
        flash.now[:alert] = "비활성화된 계정입니다. 관리자에게 문의해 주세요."
        render :new, status: :forbidden
        return
      end

      # OTP 생성 및 발송
      user.generate_otp!
      OtpMailer.send_otp(user).deliver_later

      # 이메일을 세션에 저장 (OTP 검증 단계에서 사용)
      session[:b2b_pending_email] = email
      flash[:notice] = "인증 코드가 #{email}로 발송되었습니다."
      redirect_to b2b_login_path(step: "verify")
    end

    # 2단계: OTP 검증 및 세션 생성
    def handle_verify_otp
      email = params[:email]&.strip&.downcase || session[:b2b_pending_email]
      otp_code = params[:otp_code]

      if email.blank? || otp_code.blank?
        flash.now[:alert] = "이메일과 인증 코드를 모두 입력해 주세요."
        render :new, status: :unprocessable_entity
        return
      end

      user = User.find_by(email: email)

      unless user
        flash.now[:alert] = "인증 코드가 올바르지 않거나 만료되었습니다."
        render :new, status: :unauthorized
        return
      end

      unless user.is_active
        flash.now[:alert] = "비활성화된 계정입니다."
        render :new, status: :forbidden
        return
      end

      unless user.verify_otp(otp_code)
        flash.now[:alert] = "인증 코드가 올바르지 않거나 만료되었습니다."
        render :new, status: :unprocessable_entity
        return
      end

      # 세션 초기화 및 로그인 처리
      session.delete(:b2b_pending_email)
      db_session = user.create_session!
      session[:b2b_session_token] = db_session.token

      flash[:notice] = "로그인 되었습니다. 환영합니다!"
      # 추후 B2B 대시보드로 리다이렉트
      redirect_to b2b_login_path
    end
  end
end
