# frozen_string_literal: true

# @TASK P0-T0.4 - User 모델 OTP 기능 테스트
# @TEST tests/models/user_otp_test.rb
require "test_helper"

class UserOtpTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "test-otp@example.com",
      user_type: :b2c
    )
  end

  # --- generate_otp! 테스트 ---

  test "generate_otp! 은 6자리 숫자 코드를 생성한다" do
    otp = @user.generate_otp!

    assert_not_nil otp
    assert_match(/\A\d{6}\z/, otp)
    assert_equal otp, @user.reload.otp_code
  end

  test "generate_otp! 은 otp_sent_at 을 현재 시각으로 설정한다" do
    freeze_time do
      @user.generate_otp!
      assert_equal Time.current, @user.reload.otp_sent_at
    end
  end

  test "generate_otp! 호출 시 이전 OTP가 새 코드로 덮어쓰기된다" do
    first_otp = @user.generate_otp!
    second_otp = @user.generate_otp!

    # 코드가 다를 확률이 매우 높음 (100000~999999 범위)
    # 하지만 같을 수도 있으므로 DB에 저장된 값만 확인
    assert_equal second_otp, @user.reload.otp_code
  end

  # --- verify_otp 테스트 ---

  test "verify_otp 는 올바른 코드로 true 를 반환한다" do
    otp = @user.generate_otp!

    assert @user.verify_otp(otp)
  end

  test "verify_otp 성공 후 otp_code 와 otp_sent_at 이 nil 로 초기화된다" do
    otp = @user.generate_otp!

    @user.verify_otp(otp)
    @user.reload

    assert_nil @user.otp_code
    assert_nil @user.otp_sent_at
  end

  test "verify_otp 는 잘못된 코드로 false 를 반환한다" do
    @user.generate_otp!

    assert_not @user.verify_otp("000000")
  end

  test "verify_otp 는 만료된 OTP (5분 초과) 로 false 를 반환한다" do
    otp = @user.generate_otp!

    # 5분 1초 후로 시간 이동
    travel 5.minutes + 1.second do
      assert_not @user.verify_otp(otp)
    end
  end

  test "verify_otp 는 정확히 5분 이내의 OTP 로 true 를 반환한다" do
    otp = @user.generate_otp!

    # 4분 59초 후로 시간 이동
    travel 4.minutes + 59.seconds do
      assert @user.verify_otp(otp)
    end
  end

  test "verify_otp 는 otp_code 가 nil 이면 false 를 반환한다" do
    assert_not @user.verify_otp("123456")
  end

  test "verify_otp 는 otp_sent_at 이 nil 이면 false 를 반환한다" do
    @user.update!(otp_code: "123456", otp_sent_at: nil)

    assert_not @user.verify_otp("123456")
  end

  test "verify_otp 는 같은 OTP 를 두 번 사용할 수 없다 (재사용 방지)" do
    otp = @user.generate_otp!

    assert @user.verify_otp(otp)        # 첫 번째 사용: 성공
    assert_not @user.verify_otp(otp)    # 두 번째 사용: 실패 (이미 초기화됨)
  end

  # --- OTP 없이 사용자 생성 ---

  test "비밀번호 없이 사용자를 생성할 수 있다 (OTP 전용)" do
    user = User.new(email: "otp-only@example.com", user_type: :b2c)

    assert user.valid?
    assert user.save
  end
end
